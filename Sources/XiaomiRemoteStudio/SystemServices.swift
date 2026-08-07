import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

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
