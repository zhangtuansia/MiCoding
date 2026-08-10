import CoreGraphics
import Foundation

protocol DeviceKeyRemapping: AnyObject {
    var onLog: ((String) -> Void)? { get set }
    var onEvent: ((RemoteInputEvent) -> Void)? { get set }
    var shouldPassThrough: ((RemotePhysicalKey) -> Bool)? { get set }
    var activeRemappedSlotIDs: Set<String> { get }
    @discardableResult func install() -> Bool
    func uninstall()
}

/// Routes the remote's native keyboard usages through otherwise-unused relay
/// keys. A CGEvent tap consumes those relay keys and turns them back into remote
/// events, while IOHID remains available for the back key (usage 0xF1 cannot be
/// remapped by hidutil) and as a diagnostic fallback.
final class DeviceKeyRemapper: DeviceKeyRemapping {
    typealias Mapping = (source: UInt64, destination: UInt64)
    typealias HidutilRunner = (
        _ arguments: [String],
        _ captureOutput: Bool
    ) -> (succeeded: Bool, output: String)

    struct Relay: Equatable {
        let sourceUsage: UInt32
        let destinationUsage: UInt32
        let keyCode: Int64
        let key: RemotePhysicalKey
    }

    /// F13-F20 and uncommon keypad keys have no ordinary text side effects.
    /// Back (0xF1) deliberately stays off this table because hidutil does not
    /// accept usages outside the standard keyboard-page range.
    static let relayTable: [Relay] = [
        Relay(sourceUsage: 0x4A, destinationUsage: 0x69, keyCode: 107, key: .home),
        Relay(sourceUsage: 0x65, destinationUsage: 0x6A, keyCode: 113, key: .menu),
        Relay(sourceUsage: 0x35, destinationUsage: 0x6B, keyCode: 106, key: .tv),
        Relay(sourceUsage: 0x66, destinationUsage: 0x6C, keyCode: 64, key: .power),
        Relay(sourceUsage: 0x28, destinationUsage: 0x6D, keyCode: 79, key: .ok),
        Relay(sourceUsage: 0x52, destinationUsage: 0x6E, keyCode: 80, key: .up),
        Relay(sourceUsage: 0x51, destinationUsage: 0x67, keyCode: 81, key: .down),
        Relay(sourceUsage: 0x50, destinationUsage: 0x68, keyCode: 105, key: .left),
        Relay(sourceUsage: 0x4F, destinationUsage: 0x53, keyCode: 71, key: .right),
        Relay(sourceUsage: 0x80, destinationUsage: 0x54, keyCode: 75, key: .volumeUp),
        Relay(sourceUsage: 0x81, destinationUsage: 0x55, keyCode: 67, key: .volumeDown),
        Relay(sourceUsage: 0x3E, destinationUsage: 0x6F, keyCode: 90, key: .voice)
    ]

    private static let relayByKeyCode = Dictionary(
        uniqueKeysWithValues: relayTable.map { ($0.keyCode, $0.key) }
    )
    private static let relayedSlotIDs = Set(relayTable.map { $0.key.slotID })

    private let lock = NSRecursiveLock()
    private var isInstalling = false
    private var savedForeignMappings: [Mapping]?
    private var cleanupMonitor: Process?
    private var cleanupLifetime: FileHandle?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let hidutilRunner: HidutilRunner?
    private let startsCleanupMonitor: Bool
    private let requiresEventTap: Bool
    private(set) var isInstalled = false

    var onLog: ((String) -> Void)?
    var onEvent: ((RemoteInputEvent) -> Void)?
    var shouldPassThrough: ((RemotePhysicalKey) -> Bool)?
    var activeRemappedSlotIDs: Set<String> {
        isInstalled ? Self.relayedSlotIDs : []
    }

    init(
        hidutilRunner: HidutilRunner? = nil,
        startsCleanupMonitor: Bool = true,
        requiresEventTap: Bool? = nil
    ) {
        self.hidutilRunner = hidutilRunner
        self.startsCleanupMonitor = startsCleanupMonitor
        // Injected hidutil runners are unit tests; do not make them depend on
        // the test host having Accessibility permission.
        self.requiresEventTap = requiresEventTap ?? (hidutilRunner == nil)
    }

    @discardableResult
    func install() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // A Bluetooth reconnect creates a new HID event service. The old
        // UserKeyMapping disappears with that service even though this object
        // still remembers a successful installation. Always read and reapply
        // the device-scoped mapping when the connection callback asks us to
        // install; treating `isInstalled` as authoritative makes the remote
        // silently fall back to its native keys after sleep/reconnect.
        if isInstalling { return false }
        isInstalling = true
        defer { isInstalling = false }

        guard !requiresEventTap || startEventTapIfNeeded() else {
            onLog?("无法创建按键中转监听；已保留系统原始按键")
            return false
        }

        let current = runHidutil(
            ["property", "--matching", Self.matching, "--get", "UserKeyMapping"],
            captureOutput: true
        )
        guard current.succeeded,
              let existing = Self.parseUserKeyMapping(current.output) else {
            onLog?("无法读取设备按键映射，已保留系统原始按键")
            return false
        }

        let ourSources = Set(Self.ownMappings.map(\.source))
        let foreign = existing.filter { !ourSources.contains($0.source) }
        if savedForeignMappings == nil {
            savedForeignMappings = foreign
        }

        let mappings = Self.ownMappings + foreign
        let result = runHidutil(
            ["property", "--matching", Self.matching, "--set", Self.mappingJSON(mappings)],
            captureOutput: false
        )
        isInstalled = result.succeeded
        if result.succeeded, startsCleanupMonitor {
            startCleanupMonitorIfNeeded(restoring: savedForeignMappings ?? foreign)
        }
        onLog?(result.succeeded ? "已接管遥控器原始按键" : "遥控器原始按键接管失败")
        return result.succeeded
    }

    func uninstall() {
        lock.lock()
        defer { lock.unlock() }
        guard isInstalled || savedForeignMappings != nil else { return }

        let mappings = savedForeignMappings ?? []
        let result = runHidutil(
            ["property", "--matching", Self.matching, "--set", Self.mappingJSON(mappings)],
            captureOutput: false
        )
        if result.succeeded {
            savedForeignMappings = nil
            isInstalled = false
            stopCleanupMonitor()
            stopEventTap()
        } else {
            onLog?("恢复设备原始按键映射失败")
        }
    }

    static var ownMappings: [Mapping] {
        relayTable.map {
            (
                source: 0x700000000 + UInt64($0.sourceUsage),
                destination: 0x700000000 + UInt64($0.destinationUsage)
            )
        }
    }

    static func physicalKey(forRelayKeyCode keyCode: Int64) -> RemotePhysicalKey? {
        relayByKeyCode[keyCode]
    }

    static func parseUserKeyMapping(_ text: String) -> [Mapping]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("(null)") { return [] }
        if !trimmed.contains("{") {
            if let open = trimmed.firstIndex(of: "("),
               let close = trimmed.lastIndex(of: ")"),
               open < close,
               trimmed[trimmed.index(after: open)..<close]
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return []
            }
            return nil
        }

        var mappings: [Mapping] = []
        var remaining = Substring(trimmed)
        while let open = remaining.firstIndex(of: "{") {
            guard let close = remaining[open...].firstIndex(of: "}") else { return nil }
            let block = remaining[open...close]
            guard let source = number(after: "HIDKeyboardModifierMappingSrc", in: block),
                  let destination = number(after: "HIDKeyboardModifierMappingDst", in: block) else {
                return nil
            }
            mappings.append((source, destination))
            remaining = remaining[remaining.index(after: close)...]
        }
        return mappings
    }

    private static var matching: String {
        #"{"VendorID":10007,"ProductID":12984}"#
    }

    private static func number(after key: String, in block: Substring) -> UInt64? {
        guard let range = block.range(of: key) else { return nil }
        let digits = block[range.upperBound...]
            .drop(while: { !$0.isNumber })
            .prefix(while: { $0.isNumber })
        return UInt64(digits)
    }

    private static func mappingJSON(_ mappings: [Mapping]) -> String {
        let entries = mappings.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.source),\"HIDKeyboardModifierMappingDst\":\($0.destination)}"
        }
        return "{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}"
    }

    private func runHidutil(
        _ arguments: [String],
        captureOutput: Bool
    ) -> (succeeded: Bool, output: String) {
        if let hidutilRunner {
            return hidutilRunner(arguments, captureOutput)
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = captureOutput ? pipe : FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            onLog?("无法启动 hidutil：\(error.localizedDescription)")
            return (false, "")
        }
        let data = captureOutput ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
        process.waitUntilExit()
        return (
            process.terminationStatus == 0,
            String(data: data, encoding: .utf8) ?? ""
        )
    }

    private func startCleanupMonitorIfNeeded(restoring mappings: [Mapping]) {
        guard cleanupMonitor == nil else { return }

        let lifetime = Pipe()
        let monitor = Process()
        let restoreJSON = Self.mappingJSON(mappings)
        let command = "while IFS= read -r line; do :; done; "
            + "/usr/bin/hidutil property --matching '\(Self.matching)' "
            + "--set '\(restoreJSON)' >/dev/null 2>&1"
        monitor.executableURL = URL(fileURLWithPath: "/bin/sh")
        monitor.arguments = ["-c", command]
        monitor.standardInput = lifetime
        monitor.standardOutput = FileHandle.nullDevice
        monitor.standardError = FileHandle.nullDevice
        do {
            try monitor.run()
            lifetime.fileHandleForReading.closeFile()
            cleanupMonitor = monitor
            cleanupLifetime = lifetime.fileHandleForWriting
        } catch {
            lifetime.fileHandleForReading.closeFile()
            lifetime.fileHandleForWriting.closeFile()
            onLog?("无法启动按键映射恢复守护：\(error.localizedDescription)")
        }
    }

    private func stopCleanupMonitor() {
        cleanupMonitor?.terminate()
        cleanupLifetime?.closeFile()
        cleanupMonitor = nil
        cleanupLifetime = nil
    }

    private func startEventTapIfNeeded() -> Bool {
        if let eventTap, CGEvent.tapIsEnabled(tap: eventTap) {
            return true
        }
        stopEventTap()

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByTimeout.rawValue)
            | (CGEventMask(1) << CGEventType.tapDisabledByUserInput.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: context
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        eventTap = nil
        eventTapSource = nil
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let key = Self.physicalKey(forRelayKeyCode: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        // The gesture engine owns hold timing. Repeated keyDown events would
        // continually restart that timer, so consume them without re-emitting.
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return nil
        }

        let remoteEvent = RemoteInputEvent(
            deviceID: RemoteDevice.remote2Pro.id,
            slotID: key.slotID,
            phase: type == .keyDown ? .began : .ended,
            timestamp: Date()
        )
        onEvent?(remoteEvent)

        // Typeless intentionally rejects software-generated CGEvents. When
        // its dedicated remote action is active, keep the relayed F20 event in
        // the HID stream so Typeless receives a real external-keyboard press.
        // Every other relay remains consumed exactly as before.
        return shouldPassThrough?(key) == true
            ? Unmanaged.passUnretained(event)
            : nil
    }

    private static let eventTapCallback: CGEventTapCallBack = {
        _,
        type,
        event,
        context in
        guard let context else { return Unmanaged.passUnretained(event) }
        let remapper = Unmanaged<DeviceKeyRemapper>.fromOpaque(context).takeUnretainedValue()
        return remapper.handleEventTap(type: type, event: event)
    }
}
