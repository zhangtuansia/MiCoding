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
        case .openApplicationAtPath(let path):
            openApplication(atPath: path)
        case let .controlApplication(bundleIdentifier, operation):
            controlApplication(bundleIdentifier: bundleIdentifier, operation: operation)
        case .openURL(let value):
            openURL(value)
        case .openDefaultBrowser:
            openDefaultBrowser()
        case .searchSelectedText:
            await searchSelectedText()
        case let .openURLWithSelectedTextPrompt(url, instruction):
            await openURLWithSelectedTextPrompt(url: url, instruction: instruction)
        case .typeText(let value):
            await pasteText(value)
        case .delay(let milliseconds):
            try? await Task.sleep(for: .milliseconds(max(0, milliseconds)))
        case .showActionsRing:
            NotificationCenter.default.post(name: .showActionsRingRequested, object: nil)
        case .sequence(let commands):
            for command in commands {
                guard !Task.isCancelled else { return }
                await executeNow(command)
            }
        case .none:
            break
        }
    }

    private func pasteText(_ value: String) async {
        guard !value.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        let previousItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { source in
            let copy = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        let injectedChangeCount = pasteboard.changeCount
        postKey(9, flags: .maskCommand)
        try? await Task.sleep(for: .milliseconds(80))

        guard pasteboard.changeCount == injectedChangeCount else { return }
        pasteboard.clearContents()
        if !previousItems.isEmpty {
            let writableItems: [any NSPasteboardWriting] = previousItems
            pasteboard.writeObjects(writableItems)
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
        case .previousTrack:
            postAuxiliaryKey(type: 18)
        case .nextTrack:
            postAuxiliaryKey(type: 17)
        case .volumeUp:
            postAuxiliaryKey(type: 0)
        case .volumeDown:
            postAuxiliaryKey(type: 1)
        case .mute:
            postAuxiliaryKey(type: 7)
        case .brightnessUp:
            postAuxiliaryKey(type: 2)
        case .brightnessDown:
            postAuxiliaryKey(type: 3)
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
        down.setIntegerValueField(.eventSourceUserData, value: miCodingSyntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: miCodingSyntheticEventMarker)
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

    private func openApplication(atPath path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func controlApplication(
        bundleIdentifier: String,
        operation: ApplicationActionOperation
    ) {
        switch operation {
        case .open:
            openApplication(bundleIdentifier: bundleIdentifier)
        case .close:
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .forEach { $0.terminate() }
        case .bringToFront:
            if let running = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first {
                running.activate(options: [.activateAllWindows])
            } else {
                openApplication(bundleIdentifier: bundleIdentifier)
            }
        }
    }

    private func openDefaultBrowser() {
        openURL("https://www.google.com")
    }

    private func searchSelectedText() async {
        guard let selection = await copySelectedText() else {
            openDefaultBrowser()
            return
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: selection)]
        guard let value = components?.url?.absoluteString else {
            openDefaultBrowser()
            return
        }
        openURL(value)
    }

    private func openURLWithSelectedTextPrompt(url: String, instruction: String) async {
        guard let selection = await copySelectedText(),
              let prompt = SelectedTextPromptBuilder.prompt(
                instruction: instruction,
                selection: selection
              ) else {
            openURL(url)
            return
        }

        // Keep the composed prompt on the pasteboard as a reliable fallback.
        // The ChatGPT desktop app receives it directly; the browser URL also
        // carries it for web clients that support prefilled prompts.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)

        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chat") != nil {
            openApplication(bundleIdentifier: "com.openai.chat")
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(100))
                if NSRunningApplication
                    .runningApplications(withBundleIdentifier: "com.openai.chat")
                    .contains(where: { $0.isActive }) {
                    break
                }
            }
            postKey(9, flags: .maskCommand)
            return
        }

        guard let destination = SelectedTextPromptBuilder.destinationURL(
            baseURL: url,
            prompt: prompt
        ) else {
            openURL(url)
            return
        }
        NSWorkspace.shared.open(destination)
    }

    private func copySelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        postKey(8, flags: .maskCommand)

        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(50))
            if pasteboard.changeCount != initialChangeCount { break }
        }

        guard pasteboard.changeCount != initialChangeCount,
              let selection = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !selection.isEmpty else {
            return nil
        }
        return selection
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func launchProcess(path: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}
