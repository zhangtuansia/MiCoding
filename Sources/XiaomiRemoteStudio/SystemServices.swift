import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit
import IOKit.hid
import os

private let batteryLogger = Logger(subsystem: "io.xiaomiremote.studio", category: "Battery")
private let updateLogger = Logger(subsystem: "io.xiaomiremote.studio", category: "Updates")

struct PermissionSnapshot: Equatable, Sendable {
    var accessibilityGranted: Bool
    var inputMonitoringGranted: Bool
}

enum PermissionService {
    static func current() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    static func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }
}

enum HIDDevicePresenceService {
    static func isPresent(vendorID: Int, productID: Int) -> Bool {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(kIOHIDDeviceKey),
            &iterator
        )
        guard status == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            let deviceVendorID = integerProperty(kIOHIDVendorIDKey as String, on: service)
            let deviceProductID = integerProperty(kIOHIDProductIDKey as String, on: service)
            if deviceVendorID == vendorID, deviceProductID == productID {
                return true
            }
        }
        return false
    }

    private static func integerProperty(_ key: String, on service: io_registry_entry_t) -> Int? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int
    }
}

struct BluetoothDeviceSnapshot: Equatable, Sendable {
    let batteryLevel: Int?
    let firmwareVersion: String?
}

enum BluetoothBatteryService {
    static func currentSnapshot(
        deviceName: String,
        vendorID: Int? = nil,
        productID: Int? = nil
    ) -> BluetoothDeviceSnapshot? {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        // The mini payload omits vendor/product identifiers. Keep the regular
        // payload so a renamed remote can still be matched by its HID identity.
        process.arguments = ["SPBluetoothDataType", "-json"]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            batteryLogger.error("Could not launch system_profiler: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            batteryLogger.error("system_profiler exited with status \(process.terminationStatus)")
            return nil
        }
        let snapshot = snapshot(
            in: data,
            deviceName: deviceName,
            vendorID: vendorID,
            productID: productID
        )
        batteryLogger.info(
            "Bluetooth device refresh bytes=\(data.count) level=\(snapshot?.batteryLevel.map(String.init) ?? "unreported", privacy: .public) firmware=\(snapshot?.firmwareVersion ?? "unreported", privacy: .public)"
        )
        return snapshot
    }

    static func currentLevel(
        deviceName: String,
        vendorID: Int? = nil,
        productID: Int? = nil
    ) -> Int? {
        currentSnapshot(
            deviceName: deviceName,
            vendorID: vendorID,
            productID: productID
        )?.batteryLevel
    }

    static func level(
        in data: Data,
        deviceName: String,
        vendorID: Int? = nil,
        productID: Int? = nil
    ) -> Int? {
        snapshot(
            in: data,
            deviceName: deviceName,
            vendorID: vendorID,
            productID: productID
        )?.batteryLevel
    }

    static func snapshot(
        in data: Data,
        deviceName: String,
        vendorID: Int? = nil,
        productID: Int? = nil
    ) -> BluetoothDeviceSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return snapshot(
            in: root,
            deviceName: deviceName,
            vendorID: vendorID,
            productID: productID
        )
    }

    private static func snapshot(
        in value: Any,
        deviceName: String,
        vendorID: Int?,
        productID: Int?
    ) -> BluetoothDeviceSnapshot? {
        if let dictionary = value as? [String: Any] {
            if let device = dictionary[deviceName] as? [String: Any] {
                return deviceSnapshot(from: device)
            }
            if identifiersMatch(dictionary, vendorID: vendorID, productID: productID),
               let snapshot = deviceSnapshot(from: dictionary) {
                return snapshot
            }
            for child in dictionary.values {
                if let snapshot = snapshot(
                    in: child,
                    deviceName: deviceName,
                    vendorID: vendorID,
                    productID: productID
                ) {
                    return snapshot
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let snapshot = snapshot(
                    in: child,
                    deviceName: deviceName,
                    vendorID: vendorID,
                    productID: productID
                ) {
                    return snapshot
                }
            }
        }
        return nil
    }

    private static func deviceSnapshot(from device: [String: Any]) -> BluetoothDeviceSnapshot? {
        let batteryKeys = [
            "device_batteryLevelMain",
            "device_batteryLevel",
            "device_batteryPercent"
        ]
        let snapshot = BluetoothDeviceSnapshot(
            batteryLevel: batteryKeys.lazy.compactMap { parseLevel(device[$0]) }.first,
            firmwareVersion: parseFirmwareVersion(device["device_firmwareVersion"])
        )
        return snapshot.batteryLevel != nil || snapshot.firmwareVersion != nil ? snapshot : nil
    }

    private static func identifiersMatch(
        _ device: [String: Any],
        vendorID: Int?,
        productID: Int?
    ) -> Bool {
        guard let vendorID,
              let productID,
              parseIdentifier(device["device_vendorID"]) == vendorID,
              parseIdentifier(device["device_productID"]) == productID else {
            return false
        }
        return true
    }

    private static func parseLevel(_ value: Any?) -> Int? {
        let level: Int?
        if let number = value as? NSNumber {
            level = number.intValue
        } else if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().hasPrefix("0x") {
                level = Int(trimmed.dropFirst(2), radix: 16)
            } else {
                level = Int(trimmed.filter(\.isNumber))
            }
        } else {
            level = nil
        }
        guard let level, (0...100).contains(level) else { return nil }
        return level
    }

    private static func parseFirmwareVersion(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func parseIdentifier(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            let hexadecimal = trimmed.dropFirst(2).prefix { $0.isHexDigit }
            return Int(hexadecimal, radix: 16)
        }
        let decimal = trimmed.prefix { $0.isNumber }
        return Int(decimal)
    }
}

struct SoftwareRelease: Equatable, Sendable {
    let version: String
    let pageURL: URL
}

enum SoftwareUpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case current(version: String)
    case available(SoftwareRelease)
    case unpublished
    case failed

    var message: String {
        switch self {
        case .idle:
            "尚未检查更新"
        case .checking:
            "正在检查更新…"
        case .current(let version):
            "当前 \(version) 已是最新发布版本"
        case .available(let release):
            "发现新版本 \(release.version)"
        case .unpublished:
            "项目尚未发布可下载的安装包"
        case .failed:
            "暂时无法连接更新服务"
        }
    }

    var releaseURL: URL? {
        guard case .available(let release) = self else { return nil }
        return release.pageURL
    }
}

enum SoftwareUpdateService {
    static let releasesPageURL = URL(string: "https://github.com/zhangtuansia/MiCoding/releases")!
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/zhangtuansia/MiCoding/releases/latest"
    )!

    static func latestRelease() async throws -> SoftwareRelease? {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MiCoding-macOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if response.statusCode == 404 {
            return nil
        }
        guard (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parseLatestRelease(in: data)
    }

    static func parseLatestRelease(in data: Data) throws -> SoftwareRelease {
        struct Payload: Decodable {
            let tagName: String
            let htmlURL: URL

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return SoftwareRelease(
            version: normalizedVersion(payload.tagName),
            pageURL: payload.htmlURL
        )
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = versionComponents(candidate)
        let currentParts = versionComponents(current)
        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    static func logFailure(_ error: Error) {
        updateLogger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
    }

    private static func normalizedVersion(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("v") else { return trimmed }
        return String(trimmed.dropFirst())
    }

    private static func versionComponents(_ value: String) -> [Int] {
        normalizedVersion(value)
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

@MainActor
final class FrontmostApplicationMonitor {
    var onBundleIdentifierChanged: ((String?) -> Void)?
    private var observer: NSObjectProtocol?

    var currentBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = app?.bundleIdentifier
            Task { @MainActor in
                self?.onBundleIdentifierChanged?(bundleIdentifier)
            }
        }
        onBundleIdentifierChanged?(currentBundleIdentifier)
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }
}
