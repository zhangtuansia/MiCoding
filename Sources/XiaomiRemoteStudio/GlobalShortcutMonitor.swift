import AppKit

@MainActor
final class GlobalShortcutMonitor {
    var onTrigger: ((String) -> Void)?

    private var bindings: [GlobalShortcutBinding] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var modifierStateTimer: Timer?
    private var lastObservedFunctionState = false
    private var isStarted = false
    private var activeModifierFlags: UInt64 = 0
    private var pendingModifierActionID: String?
    private var modifierGestureConsumed = false

    private static let supportedModifierMask: NSEvent.ModifierFlags = [
        .control,
        .option,
        .shift,
        .command,
        .function
    ]

    func update(bindings: [GlobalShortcutBinding]) {
        self.bindings = bindings
        updateModifierStatePolling()
    }

    func start() {
        isStarted = true
        let monitoredEvents: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        // Register the two monitors independently. macOS can reject the
        // global monitor before the relevant privacy permission is granted
        // while the local monitor succeeds; a later permission refresh must
        // still be able to fill in the missing global half.
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: monitoredEvents) { [weak self] event in
                Task { @MainActor in self?.handle(event) }
            }
        }
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: monitoredEvents) { [weak self] event in
                Task { @MainActor in self?.handle(event) }
                return event
            }
        }
        updateModifierStatePolling()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        isStarted = false
        stopModifierStatePolling()
        resetModifierGesture()
    }

    private func handle(_ event: NSEvent) {
        let isSynthetic = event.cgEvent?.getIntegerValueField(.eventSourceUserData)
            == miCodingSyntheticEventMarker
        guard let actionID = processEvent(
            type: event.type,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            isRepeat: event.isARepeat,
            isSynthetic: isSynthetic
        ) else { return }
        onTrigger?(actionID)
    }

    /// Modifier-only shortcuts are committed on release, matching the
    /// recorder. Waiting for release prevents a Command-only binding from
    /// firing first when the user actually intends to press Command-C.
    @discardableResult
    func processEvent(
        type: NSEvent.EventType,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool = false,
        isSynthetic: Bool = false
    ) -> String? {
        guard !isRepeat, !isSynthetic else { return nil }
        let flags = Self.normalizedFlags(modifierFlags)

        switch type {
        case .keyDown:
            // A system Globe action can hide fn-down from both AppKit
            // monitors, while a following ordinary key still carries the fn
            // flag. Treat that key as consuming the modifier gesture even if
            // the 10 ms hardware-state poll has not observed fn-down yet.
            if activeModifierFlags != 0 || flags != 0 {
                activeModifierFlags = flags
                pendingModifierActionID = nil
                modifierGestureConsumed = true
            }
            return Self.actionID(
                forKeyCode: keyCode,
                flags: flags,
                in: bindings
            )

        case .flagsChanged:
            lastObservedFunctionState = Self.containsFunction(flags)
            return processModifierChange(keyCode: keyCode, flags: flags)

        default:
            return nil
        }
    }

    /// Mirrors the shortcut recorder's hardware-state fallback. macOS may
    /// reserve Globe/fn for input-source switching, dictation, or the emoji
    /// panel and then omit one or both `flagsChanged` events. Polling the HID
    /// state lets the runtime reconstruct that transition without changing
    /// the release-only semantics of modifier shortcuts.
    @discardableResult
    func observeFunctionModifierState(
        currentModifiers: NSEvent.ModifierFlags
    ) -> String? {
        let modifiers = currentModifiers.intersection(Self.supportedModifierMask)
        let functionIsDown = modifiers.contains(.function)
        guard functionIsDown != lastObservedFunctionState else { return nil }
        lastObservedFunctionState = functionIsDown
        return processModifierChange(
            keyCode: 63,
            flags: Self.normalizedFlags(modifiers)
        )
    }

    private func updateModifierStatePolling() {
        guard isStarted, hasFunctionModifierBinding else {
            stopModifierStatePolling()
            return
        }
        startModifierStatePolling()
    }

    private var hasFunctionModifierBinding: Bool {
        let functionFlag = UInt64(NSEvent.ModifierFlags.function.rawValue)
        return bindings.contains {
            $0.keyCode == 63 && ($0.flags & functionFlag) != 0
        }
    }

    private func startModifierStatePolling() {
        guard modifierStateTimer == nil else { return }
        lastObservedFunctionState = Self.currentHardwareModifiers().contains(.function)
        let timer = Timer(timeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let actionID = self.observeFunctionModifierState(
                        currentModifiers: Self.currentHardwareModifiers()
                      ) else { return }
                self.onTrigger?(actionID)
            }
        }
        modifierStateTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func currentHardwareModifiers() -> NSEvent.ModifierFlags {
        var modifiers = NSEvent.modifierFlags.intersection(supportedModifierMask)
        let hardwareFlags = CGEventSource.flagsState(.hidSystemState)
        if hardwareFlags.contains(.maskSecondaryFn) {
            modifiers.insert(.function)
        }
        return modifiers
    }

    private func stopModifierStatePolling() {
        modifierStateTimer?.invalidate()
        modifierStateTimer = nil
        lastObservedFunctionState = false
    }

    private func processModifierChange(keyCode: UInt16, flags: UInt64) -> String? {
        let previousFlags = activeModifierFlags

        if previousFlags == 0, flags != 0 {
            pendingModifierActionID = nil
            modifierGestureConsumed = false
        }

        guard flags != 0 else {
            let actionID = modifierGestureConsumed ? nil : pendingModifierActionID
            resetModifierGesture()
            return actionID
        }

        defer { activeModifierFlags = flags }
        guard !modifierGestureConsumed else { return nil }

        let previousCount = previousFlags.nonzeroBitCount
        let currentCount = flags.nonzeroBitCount
        if currentCount > previousCount {
            // A newly pressed modifier replaces the previous candidate. If
            // the full chord has no binding, a shorter prefix must not fire
            // after the chord is released.
            pendingModifierActionID = Self.actionID(
                forKeyCode: keyCode,
                flags: flags,
                in: bindings
            )
        } else if currentCount == previousCount, flags != previousFlags {
            pendingModifierActionID = nil
            modifierGestureConsumed = true
        }
        return nil
    }

    private func resetModifierGesture() {
        activeModifierFlags = 0
        pendingModifierActionID = nil
        modifierGestureConsumed = false
    }

    static func actionID(
        forKeyCode keyCode: UInt16,
        flags: UInt64,
        in bindings: [GlobalShortcutBinding]
    ) -> String? {
        bindings.first(where: {
            $0.keyCode == keyCode && $0.flags == flags
        })?.actionID
    }

    static func normalizedFlags(_ flags: NSEvent.ModifierFlags) -> UInt64 {
        UInt64(flags.intersection(supportedModifierMask).rawValue)
    }

    private static func containsFunction(_ flags: UInt64) -> Bool {
        flags & UInt64(NSEvent.ModifierFlags.function.rawValue) != 0
    }
}
