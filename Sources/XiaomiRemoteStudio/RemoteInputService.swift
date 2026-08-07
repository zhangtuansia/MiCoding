import Foundation
import IOKit.hid

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

    init(vendorID: Int = 0x2717, productID: Int = 0x32B8) {
        self.vendorID = vendorID
        self.productID = productID
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
        onConnectionChanged?(false)
    }

    private func handleInput(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        guard usagePage == 0x07 else { return }

        let usage = IOHIDElementGetUsage(element)
        guard usage != UInt32.max else { return }
        let isDown = IOHIDValueGetIntegerValue(value) != 0

        guard let key = RemotePhysicalKey.usageMap[usage] else {
            onUnknownUsage?(usage, isDown)
            return
        }

        onEvent?(
            RemoteInputEvent(
                deviceID: RemoteDevice.remote2Pro.id,
                slotID: key.slotID,
                phase: isDown ? .began : .ended,
                timestamp: Date()
            )
        )
    }

    private static let inputCallback: IOHIDValueCallback = { context, _, _, value in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        service.handleInput(value)
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        service.onConnectionChanged?(true)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let service = Unmanaged<IOHIDRemoteInputService>.fromOpaque(context).takeUnretainedValue()
        service.onConnectionChanged?(false)
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
