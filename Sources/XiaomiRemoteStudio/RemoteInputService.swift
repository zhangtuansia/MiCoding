import Foundation
import IOKit.hid
import os

private let hidLogger = Logger(subsystem: "io.xiaomiremote.studio", category: "HID")

enum RemoteInputPhase: Sendable {
    case began
    case ended
}

struct RemoteInputEvent: Sendable {
    let deviceID: String
    let slotID: String
    let phase: RemoteInputPhase
    let timestamp: Date
}

protocol RemoteInputServicing: AnyObject {
    var onEvent: ((RemoteInputEvent) -> Void)? { get set }
    var onConnectionChanged: ((Bool) -> Void)? { get set }
    var onUnknownUsage: ((UInt32, Bool) -> Void)? { get set }
    func start() throws
    func stop()
}

enum RemoteInputServiceError: LocalizedError {
    case couldNotOpen(Int32)

    var errorDescription: String? {
        switch self {
        case .couldNotOpen(let status):
            "无法打开 HID 监听器（状态码 \(status)）"
        }
    }
}

/// Real Xiaomi Remote 2 Pro input source.
///
/// It listens instead of seizing the Bluetooth keyboard. Suppressing the original
/// macOS behavior is a separate, permission-gated routing concern; input discovery
/// and UI feedback still work when that routing layer is disabled.
final class IOHIDRemoteInputService: RemoteInputServicing, @unchecked Sendable {
    var onEvent: ((RemoteInputEvent) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var onUnknownUsage: ((UInt32, Bool) -> Void)?

    private let vendorID: Int
    private let productID: Int
    private var manager: IOHIDManager?
    private var reportUsages: Set<UInt32> = []
    private var reportFlushScheduled = false
    private var rawReportsObserved = false
    private var stateTracker = RemoteHIDStateTracker()
    private var isConnected = false

    init(vendorID: Int = 0x2717, productID: Int = 0x32B8) {
        self.vendorID = vendorID
        self.productID = productID
    }

    deinit {
        // IOHIDManager stores an unretained callback context. Unschedule and
        // close it before this object disappears so a delayed initial-enumeration
        // callback can never dereference a released service.
        stop()
    }

    func start() throws {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        self.manager = manager

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: vendorID,
            kIOHIDProductIDKey as String: productID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, Self.inputCallback, context)
        IOHIDManagerRegisterInputReportCallback(manager, Self.inputReportCallback, context)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceRemovedCallback, context)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            stop()
            throw RemoteInputServiceError.couldNotOpen(status)
        }

        // Matching callbacks normally enumerate devices already present when
        // the manager opens, but that callback can be delayed on the BLE HID
        // path. Query the manager as well so a connected remote cannot remain
        // stuck in "starting" while its native keys have already been muted.
        let matchedDeviceCount = IOHIDManagerCopyDevices(manager)
            .map(CFSetGetCount) ?? 0
        hidLogger.info(
            "manager opened status=0 matchedDevices=\(matchedDeviceCount)"
        )
        if matchedDeviceCount > 0 {
            reportConnectionChange(true)
        }
    }

    func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        reportUsages.removeAll()
        reportFlushScheduled = false
        rawReportsObserved = false
        stateTracker.reset()
        reportConnectionChange(false)
    }

    private func handleInput(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        guard usagePage == 0x07 else { return }

        let usage = IOHIDElementGetUsage(element)
        let rawValue = IOHIDValueGetIntegerValue(value)
        hidLogger.debug("value page=0x07 usage=\(usage, format: .hex) value=\(rawValue)")
        let valueLength = IOHIDValueGetLength(value)
        if usage == UInt32.max,
           valueLength >= RemoteHIDReportParser.keyboardArrayPayloadLength {
            let bytes = Array(
                UnsafeBufferPointer(
                    start: IOHIDValueGetBytePtr(value),
                    count: valueLength
                )
            )
            reportUsages.formUnion(
                RemoteHIDReportParser.keyboardArrayUsages(bytes: bytes) ?? []
            )
        } else if let resolvedUsage = RemoteHIDReportParser.keyboardUsage(
            elementUsage: usage,
            integerValue: rawValue
        ) {
            // Track mapped and unmapped usages through the same report diff.
            // This avoids repeated "down" diagnostics for one held key and also
            // reports the corresponding release for firmware-specific usages.
            reportUsages.insert(resolvedUsage)
        }

        // This remote exposes three HID array slots per report. Empty slots arrive
        // as usage 0xFFFFFFFF/value -1 rather than as value 0 for the previous key.
        // Coalesce all value callbacks from one run-loop delivery, then diff the
        // complete usage set so releases, chords and gesture timing stay correct.
        guard !reportFlushScheduled else { return }
        reportFlushScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushReport()
        }
    }

    private func flushReport() {
        reportFlushScheduled = false
        guard !rawReportsObserved else {
            reportUsages.removeAll()
            return
        }
        process(usages: reportUsages, source: "value")
        reportUsages.removeAll()
    }

    private func handleInputReport(
        result: IOReturn,
        type: IOHIDReportType,
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>?,
        reportLength: CFIndex
    ) {
        guard result == kIOReturnSuccess,
              type == kIOHIDReportTypeInput,
              let report,
              reportLength > 0 else { return }

        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))

        // Keep report-ID 1 observable even when a firmware variant does not
        // match the parser below. Physical button presses are infrequent, so
        // this is cheap and turns future compatibility failures into concrete
        // byte layouts instead of a silent no-op.
        if reportID == 1 || (reportID == 0 && bytes.first == 1) {
            let byteText = bytes.prefix(16)
                .map { String(format: "%02X", $0) }
                .joined(separator: " ")
            hidLogger.info(
                "keyboard report id=\(reportID) bytes=[\(byteText, privacy: .public)] length=\(reportLength)"
            )
        }

        guard let usages = RemoteHIDReportParser.keyboardUsages(
            reportID: reportID,
            bytes: bytes
        ) else { return }

        rawReportsObserved = true
        process(usages: usages, source: "raw")
    }

    private func process(usages: Set<UInt32>, source: String) {
        let changes = stateTracker.update(with: usages)
        let usageText = usages.sorted().map { String(format: "0x%02X", $0) }.joined(separator: ",")
        hidLogger.info(
            "\(source, privacy: .public) report usages=[\(usageText, privacy: .public)] changes=\(changes.count)"
        )

        for change in changes {
            if let key = RemotePhysicalKey.usageMap[change.usage] {
                onEvent?(
                    RemoteInputEvent(
                        deviceID: RemoteDevice.remote2Pro.id,
                        slotID: key.slotID,
                        phase: change.isDown ? .began : .ended,
                        timestamp: Date()
                    )
                )
            } else {
                onUnknownUsage?(change.usage, change.isDown)
            }
        }
    }

    private func reportConnectionChange(_ connected: Bool) {
        guard isConnected != connected else { return }
        isConnected = connected
        onConnectionChanged?(connected)
    }

    private static let inputCallback: IOHIDValueCallback = { context, _, _, value in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        service.handleInput(value)
    }

    private static let inputReportCallback: IOHIDReportCallback = {
        context,
        result,
        _,
        type,
        reportID,
        report,
        reportLength in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        service.handleInputReport(
            result: result,
            type: type,
            reportID: reportID,
            report: report,
            reportLength: reportLength
        )
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        hidLogger.info("matched Xiaomi Remote HID device")
        service.reportConnectionChange(true)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        hidLogger.info("removed Xiaomi Remote HID device")
        service.reportConnectionChange(false)
    }
}

/// Parser for the remote's report-ID 1 keyboard payload. Its descriptor
/// declares three little-endian 16-bit array slots; an empty slot is reported
/// as either 0 or 0xFFFF depending on the macOS HID path. Reports 6-8 belong to
/// the vendor/voice channel and must never be interpreted as buttons.
enum RemoteHIDReportParser {
    static let keyboardArraySlotCount = 3
    static let keyboardArrayPayloadLength = keyboardArraySlotCount * 2

    /// Resolves the payload delivered through IOHID's value callback.
    ///
    /// The Xiaomi remote declares report 1 as a three-entry keyboard *array*.
    /// For array elements macOS exposes an element usage of `0xFFFFFFFF`; the
    /// actual keyboard usage is carried by the integer value. Variable keyboard
    /// elements use the conventional element-usage/value-is-down representation.
    static func keyboardUsage(elementUsage: UInt32, integerValue: CFIndex) -> UInt32? {
        if elementUsage == UInt32.max {
            guard integerValue > 0, integerValue <= 0xFE else { return nil }
            return UInt32(integerValue)
        }

        guard elementUsage > 0,
              elementUsage <= 0xFE,
              integerValue != 0 else { return nil }
        return elementUsage
    }

    static func keyboardUsages(reportID: UInt32, bytes: [UInt8]) -> Set<UInt32>? {
        let includesReportID: Bool
        switch reportID {
        case 1:
            // Some manager paths omit the report ID from the buffer, while
            // others leave it as the first byte.
            includesReportID = bytes.first == 1
        case 0:
            // A zero callback ID is only accepted when the buffer explicitly
            // identifies keyboard report 1. Never infer report 1 from the
            // payload of known vendor/voice reports 6-8.
            guard bytes.first == 1 else { return nil }
            includesReportID = true
        default:
            return nil
        }

        let payloadStart = includesReportID ? 1 : 0
        guard bytes.count >= payloadStart + keyboardArrayPayloadLength else { return nil }

        return keyboardArrayUsages(bytes: Array(bytes.dropFirst(payloadStart)))
    }

    /// Parses the report-1 element bytes used by IOHID's value callback. The
    /// bytes do not include the report ID and preserve the three 16-bit slots.
    static func keyboardArrayUsages(bytes: [UInt8]) -> Set<UInt32>? {
        guard bytes.count >= keyboardArrayPayloadLength else { return nil }

        var usages: Set<UInt32> = []
        for slot in 0..<keyboardArraySlotCount {
            let index = slot * 2
            let usage = UInt32(bytes[index]) | (UInt32(bytes[index + 1]) << 8)
            guard usage != 0, usage != 0xFFFF, usage <= 0xFE else { continue }
            usages.insert(usage)
        }
        return usages
    }
}

struct RemoteHIDStateChange: Equatable, Sendable {
    let usage: UInt32
    let isDown: Bool
}

struct RemoteHIDStateTracker: Sendable {
    private(set) var pressedUsages: Set<UInt32> = []

    mutating func update(with usages: Set<UInt32>) -> [RemoteHIDStateChange] {
        let released = pressedUsages.subtracting(usages).sorted()
        let pressed = usages.subtracting(pressedUsages).sorted()
        pressedUsages = usages
        return released.map { RemoteHIDStateChange(usage: $0, isDown: false) }
            + pressed.map { RemoteHIDStateChange(usage: $0, isDown: true) }
    }

    mutating func reset() {
        pressedUsages.removeAll()
    }
}

final class PreviewRemoteInputService: RemoteInputServicing {
    var onEvent: ((RemoteInputEvent) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?
    var onUnknownUsage: ((UInt32, Bool) -> Void)?

    func start() throws {
        onConnectionChanged?(true)
    }

    func stop() {
        onConnectionChanged?(false)
    }

    func emit(slotID: String, phase: RemoteInputPhase) {
        onEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: slotID,
                phase: phase,
                timestamp: Date()
            )
        )
    }
}
