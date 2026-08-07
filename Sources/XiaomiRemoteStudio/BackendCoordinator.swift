import Foundation

@MainActor
final class BackendCoordinator {
    var resolveActionID: ((String?, String, RemoteTrigger) -> String?)?
    var onInputEvent: ((RemoteInputEvent) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var onLog: ((String) -> Void)?

    private let inputService: RemoteInputServicing
    private let gestureEngine: RemoteGestureEngine
    private let executor: any ActionExecuting
    private let applicationMonitor: FrontmostApplicationMonitor
    private var activeBundleIdentifier: String?
    private var started = false

    init(
        inputService: RemoteInputServicing = IOHIDRemoteInputService(),
        gestureEngine: RemoteGestureEngine = RemoteGestureEngine(),
        executor: any ActionExecuting = SystemActionExecutor(),
        applicationMonitor: FrontmostApplicationMonitor = FrontmostApplicationMonitor()
    ) {
        self.inputService = inputService
        self.gestureEngine = gestureEngine
        self.executor = executor
        self.applicationMonitor = applicationMonitor
        wireServices()
    }

    func configure(settings: BackendSettings) {
        gestureEngine.holdMilliseconds = settings.holdMilliseconds
        gestureEngine.doubleTapMilliseconds = settings.doubleTapMilliseconds
    }

    func start() {
        guard !started else { return }
        started = true
        applicationMonitor.start()
        do {
            try inputService.start()
            onLog?("HID 监听器已启动，等待 Xiaomi Remote 2 Pro")
        } catch {
            onConnectionChanged?(false)
            onLog?(error.localizedDescription)
        }
    }

    func stop() {
        guard started else { return }
        started = false
        inputService.stop()
        applicationMonitor.stop()
        gestureEngine.reset()
    }

    func execute(actionID: String, source: String) {
        let command = ActionCommand.command(for: actionID)
        guard command != .none else {
            onLog?("动作 \(actionID) 尚无可用执行器")
            return
        }
        executor.execute(command)
        onLog?("\(source) → \(actionID)")
    }

    private func wireServices() {
        inputService.onEvent = { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                self.onInputEvent?(event)
                self.gestureEngine.handle(event)
            }
        }

        inputService.onConnectionChanged = { [weak self] connected in
            Task { @MainActor in
                self?.onConnectionChanged?(connected)
                if !connected {
                    self?.gestureEngine.reset()
                }
            }
        }

        inputService.onUnknownUsage = { [weak self] usage, isDown in
            Task { @MainActor in
                self?.onLog?(String(format: "检测到未知 HID usage 0x%02X (%@)", usage, isDown ? "down" : "up"))
            }
        }

        applicationMonitor.onBundleIdentifierChanged = { [weak self] bundleIdentifier in
            self?.activeBundleIdentifier = bundleIdentifier
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
            self.execute(
                actionID: actionID,
                source: "执行 \(resolved.slotID).\(resolved.trigger.rawValue)"
            )
        }
    }
}
