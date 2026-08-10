import Foundation
import os

private let backendLogger = Logger(subsystem: "io.xiaomiremote.studio", category: "Backend")

@MainActor
final class BackendCoordinator {
    var resolveActionID: ((String?, String, RemoteTrigger) -> String?)?
    var resolveCommand: ((String) -> ActionCommand?)?
    var onInputEvent: ((RemoteInputEvent) -> Void)?
    var onVoiceReport: ((RemoteVoiceReport) -> Void)?
    var onUnknownUsage: ((UInt32, Bool) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var onLog: ((String) -> Void)?

    private let inputService: RemoteInputServicing
    private let gestureEngine: RemoteGestureEngine
    private let executor: any ActionExecuting
    private let applicationMonitor: FrontmostApplicationMonitor
    private let keyRemapper: (any DeviceKeyRemapping)?
    private let shortcutMonitor: GlobalShortcutMonitor
    private var applicationTriggerBindings: [ApplicationTriggerBinding] = []
    private var lastApplicationTriggerDates: [String: Date] = [:]
    private var activeBundleIdentifier: String?
    private var inputStarted = false
    private var automationTriggersStarted = false

    init(
        inputService: RemoteInputServicing = IOHIDRemoteInputService(),
        gestureEngine: RemoteGestureEngine = RemoteGestureEngine(),
        executor: any ActionExecuting = SystemActionExecutor(),
        applicationMonitor: FrontmostApplicationMonitor = FrontmostApplicationMonitor(),
        keyRemapper: (any DeviceKeyRemapping)? = DeviceKeyRemapper(),
        shortcutMonitor: GlobalShortcutMonitor = GlobalShortcutMonitor()
    ) {
        self.inputService = inputService
        self.gestureEngine = gestureEngine
        self.executor = executor
        self.applicationMonitor = applicationMonitor
        self.keyRemapper = keyRemapper
        self.shortcutMonitor = shortcutMonitor
        wireServices()
    }

    func configure(settings: BackendSettings) {
        gestureEngine.holdMilliseconds = settings.holdMilliseconds
        gestureEngine.doubleTapMilliseconds = settings.doubleTapMilliseconds
        gestureEngine.debounceMilliseconds = settings.debounceMilliseconds ?? 30
    }

    func configure(shortcutBindings: [GlobalShortcutBinding]) {
        shortcutMonitor.update(bindings: shortcutBindings)
    }

    func configure(applicationTriggerBindings: [ApplicationTriggerBinding]) {
        self.applicationTriggerBindings = applicationTriggerBindings
    }

    func start() {
        startAutomationTriggers()
        guard !inputStarted else { return }
        do {
            try inputService.start()
            inputStarted = true
            onLog?("HID 监听器已启动，等待 Xiaomi Remote 2 Pro")
        } catch {
            onConnectionChanged?(false)
            onLog?(error.localizedDescription)
        }
    }

    func startAutomationTriggers() {
        guard !automationTriggersStarted else { return }
        automationTriggersStarted = true
        applicationMonitor.start()
        shortcutMonitor.start()
    }

    func stop() {
        stopInput()
        if automationTriggersStarted {
            automationTriggersStarted = false
            shortcutMonitor.stop()
            applicationMonitor.stop()
        }
        lastApplicationTriggerDates.removeAll()
    }

    /// Stops device interception without disabling app/shortcut automations.
    /// This is used when Input Monitoring is revoked while the app is running:
    /// the hidutil mapping must be removed immediately or the remote becomes a
    /// swallowed-key device with no listener able to execute the replacement.
    func stopInput() {
        if inputStarted {
            inputStarted = false
            inputService.stop()
            keyRemapper?.uninstall()
        }
        gestureEngine.reset()
    }

    func execute(actionID: String, source: String) {
        backendLogger.info("execute action=\(actionID, privacy: .public) source=\(source, privacy: .public)")
        let command = resolveCommand?(actionID) ?? ActionCommand.command(for: actionID)
        execute(command: command, source: source, logIdentifier: actionID)
    }

    func execute(command: ActionCommand, source: String) {
        backendLogger.info("execute preview source=\(source, privacy: .public)")
        execute(command: command, source: source, logIdentifier: "preview")
    }

    private func execute(command: ActionCommand, source: String, logIdentifier: String) {
        guard command != .none else {
            onLog?("动作 \(logIdentifier) 尚无可用执行器")
            return
        }
        executor.execute(command)
        onLog?("\(source) → \(logIdentifier)")
    }

    private func wireServices() {
        shortcutMonitor.onTrigger = { [weak self] actionID in
            self?.execute(actionID: actionID, source: "快捷键触发器")
        }
        keyRemapper?.onLog = { [weak self] message in
            Task { @MainActor in self?.onLog?(message) }
        }
        keyRemapper?.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.routeInputEvent(event)
            }
        }
        keyRemapper?.shouldPassThrough = { [weak self] key in
            guard let self, key == .voice else { return false }
            return self.resolveActionID?(
                self.activeBundleIdentifier,
                key.slotID,
                .tap
            ) == "typeless-dictation"
                && self.resolveActionID?(
                    self.activeBundleIdentifier,
                    key.slotID,
                    .hold
                ) == nil
                && self.resolveActionID?(
                    self.activeBundleIdentifier,
                    key.slotID,
                    .doubleTap
                ) == nil
        }
        inputService.onEvent = { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                // hidutil relay keys are the authoritative path for standard
                // keyboard usages. IOHID remains authoritative for back 0xF1
                // and becomes the fallback for every key if relay setup fails.
                guard self.keyRemapper?.activeRemappedSlotIDs.contains(event.slotID) != true else {
                    return
                }
                self.routeInputEvent(event)
            }
        }

        inputService.onVoiceReport = { [weak self] report in
            Task { @MainActor in
                self?.onVoiceReport?(report)
            }
        }

        inputService.onConnectionChanged = { [weak self] connected in
            Task { @MainActor in
                guard let self, self.inputStarted else { return }
                self.onConnectionChanged?(connected)
                if connected {
                    _ = self.keyRemapper?.install()
                } else {
                    self.gestureEngine.reset()
                }
            }
        }

        inputService.onUnknownUsage = { [weak self] usage, isDown in
            Task { @MainActor in
                self?.onUnknownUsage?(usage, isDown)
                self?.onLog?(String(format: "检测到未知 HID usage 0x%02X (%@)", usage, isDown ? "down" : "up"))
            }
        }

        applicationMonitor.onBundleIdentifierChanged = { [weak self] bundleIdentifier in
            guard let self else { return }
            self.activeBundleIdentifier = bundleIdentifier
            for actionID in Self.applicationActionIDs(
                for: bundleIdentifier,
                in: self.applicationTriggerBindings
            ) {
                let now = Date()
                if let previousDate = self.lastApplicationTriggerDates[actionID],
                   now.timeIntervalSince(previousDate) < 1 {
                    continue
                }
                self.lastApplicationTriggerDates[actionID] = now
                self.execute(actionID: actionID, source: "应用触发器")
            }
        }

        gestureEngine.hasBinding = { [weak self] slotID, trigger in
            guard let self else { return false }
            return self.resolveActionID?(self.activeBundleIdentifier, slotID, trigger) != nil
        }

        gestureEngine.onResolvedTrigger = { [weak self] resolved in
            guard let self,
                  let actionID = self.resolveActionID?(
                    self.activeBundleIdentifier,
                    resolved.slotID,
                    resolved.trigger
                  ) else {
                return
            }
            if resolved.slotID == RemotePhysicalKey.voice.slotID,
               resolved.trigger == .tap,
               actionID == "typeless-dictation" {
                self.onLog?("执行 voice.tap → typeless-dictation（硬件 F20）")
                return
            }
            self.execute(
                actionID: actionID,
                source: "执行 \(resolved.slotID).\(resolved.trigger.rawValue)"
            )
        }
    }

    private func routeInputEvent(_ event: RemoteInputEvent) {
        backendLogger.info(
            "input slot=\(event.slotID, privacy: .public) phase=\(String(describing: event.phase), privacy: .public)"
        )
        onInputEvent?(event)
        gestureEngine.handle(event)
    }

    static func applicationActionIDs(
        for bundleIdentifier: String?,
        in bindings: [ApplicationTriggerBinding]
    ) -> [String] {
        guard let bundleIdentifier else { return [] }
        return bindings.compactMap {
            $0.bundleIdentifier == bundleIdentifier ? $0.actionID : nil
        }
    }
}
