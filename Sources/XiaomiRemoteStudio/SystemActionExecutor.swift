import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol ActionExecuting: AnyObject {
    func execute(_ command: ActionCommand)
}

@MainActor
final class SystemActionExecutor: ActionExecuting {
    func execute(_ command: ActionCommand) {
        Task { @MainActor [weak self] in
            await self?.executeNow(command)
        }
    }

    private func executeNow(_ command: ActionCommand) async {
        switch command {
        case .keyStroke(let keyCode, let rawFlags):
            postKey(CGKeyCode(keyCode), flags: CGEventFlags(rawValue: rawFlags))
        case .system(let action):
            executeSystemAction(action)
        case .openApplication(let bundleIdentifier):
            openApplication(bundleIdentifier: bundleIdentifier)
        case .openDefaultBrowser:
            openDefaultBrowser()
        case .delay(let milliseconds):
            try? await Task.sleep(for: .milliseconds(max(0, milliseconds)))
        case .sequence(let commands):
            for command in commands {
                guard !Task.isCancelled else { return }
                await executeNow(command)
            }
        case .none:
            break
        }
    }

    private func executeSystemAction(_ action: SystemActionName) {
        switch action {
        case .spotlight:
            postKey(49, flags: .maskCommand)
        case .missionControl:
            launchProcess(path: "/usr/bin/open", arguments: ["-a", "Mission Control"])
        case .showDesktop:
            postKey(103, flags: [])
        case .lockScreen:
            postKey(12, flags: [.maskCommand, .maskControl])
        case .screenshotRegion:
            postKey(21, flags: [.maskCommand, .maskShift])
        case .playPause:
            postAuxiliaryKey(type: 16)
        case .nextTrack:
            postAuxiliaryKey(type: 17)
        case .volumeUp:
            postAuxiliaryKey(type: 0)
        case .volumeDown:
            postAuxiliaryKey(type: 1)
        case .mute:
            postAuxiliaryKey(type: 7)
        }
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postAuxiliaryKey(type: Int32) {
        func post(isDown: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00)
            let data1 = (Int(type) << 16) | ((isDown ? 0xA : 0xB) << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }

        post(isDown: true)
        post(isDown: false)
    }

    private func openApplication(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func openDefaultBrowser() {
        guard let probeURL = URL(string: "https://example.com"),
              let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
    }

    private func launchProcess(path: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}
