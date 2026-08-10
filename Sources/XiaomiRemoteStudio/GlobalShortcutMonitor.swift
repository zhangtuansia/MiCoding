import AppKit

@MainActor
final class GlobalShortcutMonitor {
    var onTrigger: ((String) -> Void)?

    private var bindings: [GlobalShortcutBinding] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func update(bindings: [GlobalShortcutBinding]) {
        self.bindings = bindings
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
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
    }

    private func handle(_ event: NSEvent) {
        guard !event.isARepeat,
              event.cgEvent?.getIntegerValueField(.eventSourceUserData)
                != miCodingSyntheticEventMarker else { return }
        let flags = Self.normalizedFlags(event.modifierFlags)
        guard let actionID = Self.actionID(
            forKeyCode: event.keyCode,
            flags: flags,
            in: bindings
        ) else { return }
        onTrigger?(actionID)
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
        UInt64(
            flags.intersection([.control, .option, .shift, .command]).rawValue
        )
    }
}
