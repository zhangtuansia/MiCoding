import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
protocol ActionExecuting: AnyObject {
    func execute(_ command: ActionCommand) async -> ActionExecutionResult
}

enum ActionExecutionResult: Equatable, Sendable {
    case success
    case failure(String)

    var failureMessage: String? {
        guard case let .failure(message) = self else { return nil }
        return message
    }
}

@MainActor
final class SystemActionExecutor: ActionExecuting {
    func execute(_ command: ActionCommand) async -> ActionExecutionResult {
        switch command {
        case .keyStroke(let keyCode, let rawFlags):
            return postKey(CGKeyCode(keyCode), flags: CGEventFlags(rawValue: rawFlags))
                ? .success
                : .failure(eventPostingFailureMessage(for: "键盘事件"))
        case .system(let action):
            return executeSystemAction(action)
        case .openApplication(let bundleIdentifier):
            return await openApplication(bundleIdentifier: bundleIdentifier)
        case .openApplicationAtPath(let path):
            return await openApplication(atPath: path)
        case .focusApplicationInput(let bundleIdentifier):
            return await focusApplicationInput(bundleIdentifier: bundleIdentifier)
        case let .controlApplication(bundleIdentifier, operation):
            return await controlApplication(
                bundleIdentifier: bundleIdentifier,
                operation: operation
            )
        case .openURL(let value):
            return openURL(value)
        case .openDefaultBrowser:
            return openDefaultBrowser()
        case .searchSelectedText:
            return await searchSelectedText()
        case let .openURLWithSelectedTextPrompt(url, instruction):
            return await openURLWithSelectedTextPrompt(url: url, instruction: instruction)
        case .typeText(let value):
            return await pasteText(value)
        case .delay(let milliseconds):
            do {
                try await Task.sleep(for: .milliseconds(max(0, milliseconds)))
                return .success
            } catch {
                return .failure("动作已取消")
            }
        case .startDictation:
            return await startDictation()
        case .hardwareKeyPassThrough:
            return .success
        case .showActionsRing:
            NotificationCenter.default.post(name: .showActionsRingRequested, object: nil)
            return .success
        case .sequence(let commands):
            guard !commands.isEmpty else {
                return .failure("动作序列为空")
            }
            for (index, command) in commands.enumerated() {
                guard !Task.isCancelled else { return .failure("动作已取消") }
                if case let .failure(message) = await execute(command) {
                    return .failure("第 \(index + 1) 步失败：\(message)")
                }
            }
            return .success
        case .none:
            return .failure("此动作尚无可用执行器")
        }
    }

    private func pasteText(_ value: String) async -> ActionExecutionResult {
        guard !value.isEmpty else { return .failure("要输入的文本为空") }
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
        guard postKey(9, flags: .maskCommand) else {
            restorePasteboard(previousItems)
            return .failure(eventPostingFailureMessage(for: "粘贴键盘事件"))
        }
        do {
            try await Task.sleep(for: .milliseconds(80))
        } catch {
            restorePasteboard(previousItems)
            return .failure("动作已取消")
        }

        guard pasteboard.changeCount == injectedChangeCount else { return .success }
        restorePasteboard(previousItems)
        return .success
    }

    private func restorePasteboard(_ previousItems: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !previousItems.isEmpty else { return }
        let writableItems: [any NSPasteboardWriting] = previousItems
        pasteboard.writeObjects(writableItems)
    }

    private func executeSystemAction(_ action: SystemActionName) -> ActionExecutionResult {
        switch action {
        case .spotlight:
            return keyboardResult(postKey(49, flags: .maskCommand))
        case .missionControl:
            return launchProcess(path: "/usr/bin/open", arguments: ["-a", "Mission Control"])
        case .showDesktop:
            return keyboardResult(postKey(103, flags: []))
        case .lockScreen:
            return keyboardResult(postKey(12, flags: [.maskCommand, .maskControl]))
        case .screenshotRegion:
            return keyboardResult(postKey(21, flags: [.maskCommand, .maskShift]))
        case .playPause:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 16))
        case .previousTrack:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 18))
        case .nextTrack:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 17))
        case .volumeUp:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 0))
        case .volumeDown:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 1))
        case .mute:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 7))
        case .brightnessUp:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 2))
        case .brightnessDown:
            return auxiliaryKeyResult(postAuxiliaryKey(type: 3))
        }
    }

    private func keyboardResult(_ posted: Bool) -> ActionExecutionResult {
        posted ? .success : .failure(eventPostingFailureMessage(for: "键盘事件"))
    }

    private func auxiliaryKeyResult(_ posted: Bool) -> ActionExecutionResult {
        posted ? .success : .failure(eventPostingFailureMessage(for: "媒体键事件"))
    }

    private func eventPostingFailureMessage(for eventName: String) -> String {
        AXIsProcessTrusted()
            ? "无法创建\(eventName)"
            : "未获得辅助功能权限，无法发送\(eventName)"
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        if let modifierFlag = modifierFlag(for: keyCode),
           flags.contains(modifierFlag),
           flags.subtracting(modifierFlag).isEmpty {
            return postModifierTap(keyCode: keyCode, flag: modifierFlag)
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: miCodingSyntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: miCodingSyntheticEventMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private func modifierFlag(for keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 63: .maskSecondaryFn
        case 59, 62: .maskControl
        case 56, 60: .maskShift
        case 58, 61: .maskAlternate
        case 54, 55: .maskCommand
        default: nil
        }
    }

    /// Modifier-only shortcuts arrive as `flagsChanged` events on real
    /// keyboards. Posting a regular keyDown/keyUp pair (and leaving the flag
    /// set on keyUp) is why recorded fn shortcuts were visible in MiCoding but
    /// ignored by apps that monitor modifiers directly.
    private func postModifierTap(keyCode: CGKeyCode, flag: CGEventFlags) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard postModifierEvent(keyCode: keyCode, isDown: true, flags: flag, source: source) else {
            return false
        }
        return postModifierEvent(keyCode: keyCode, isDown: false, flags: [], source: source)
    }

    private func postModifierEvent(
        keyCode: CGKeyCode,
        isDown: Bool,
        flags: CGEventFlags,
        source: CGEventSource?
    ) -> Bool {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: isDown
        ) else { return false }
        event.type = .flagsChanged
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: miCodingSyntheticEventMarker)
        event.post(tap: .cghidEventTap)
        return true
    }

    private func postAuxiliaryKey(type: Int32) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        func post(isDown: Bool) -> Bool {
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
            guard let cgEvent = event?.cgEvent else { return false }
            cgEvent.post(tap: .cghidEventTap)
            return true
        }

        return post(isDown: true) && post(isDown: false)
    }

    private func openApplication(bundleIdentifier: String) async -> ActionExecutionResult {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return .failure("未找到应用（\(bundleIdentifier)）")
        }
        return await openApplication(at: url, displayName: bundleIdentifier)
    }

    private func openApplication(atPath path: String) async -> ActionExecutionResult {
        let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame,
              FileManager.default.fileExists(atPath: url.path) else {
            return .failure("应用路径无效：\(path)")
        }
        return await openApplication(at: url, displayName: url.lastPathComponent)
    }

    private func openApplication(at url: URL, displayName: String) async -> ActionExecutionResult {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(
                        returning: .failure("无法打开应用 \(displayName)：\(error.localizedDescription)")
                    )
                } else {
                    continuation.resume(returning: .success)
                }
            }
        }
    }

    /// Focuses the prompt composer without relying on app-specific keyboard
    /// shortcuts. Both Codex and Claude expose the actual editor as an
    /// accessibility text area, even though it is deeply nested in web views.
    /// A point hit-test near the bottom of the active window reaches that
    /// editor immediately and avoids walking a very large accessibility tree.
    private func focusApplicationInput(bundleIdentifier: String) async -> ActionExecutionResult {
        let supportedBundleIdentifiers = [
            "com.openai.codex",
            "com.anthropic.claudefordesktop"
        ]
        guard supportedBundleIdentifiers.contains(bundleIdentifier) else {
            return .failure("此应用暂不支持自动聚焦输入框")
        }
        guard AXIsProcessTrusted() else {
            return .failure("未获得辅助功能权限，无法聚焦应用输入框")
        }

        if NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .isEmpty {
            if case let .failure(message) = await openApplication(bundleIdentifier: bundleIdentifier) {
                return .failure(message)
            }
        }

        // Cold-starting either Electron app can take a few seconds. Retry
        // long enough for its first window and web accessibility tree to load.
        for _ in 0..<40 {
            guard let running = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first else {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            guard running.activate(options: [.activateAllWindows]) else {
                return .failure("无法将应用置于前台")
            }
            if focusPromptTextArea(processIdentifier: running.processIdentifier) {
                return .success
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return .failure("无法聚焦应用输入框，请检查辅助功能权限")
    }

    private func focusPromptTextArea(processIdentifier: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let window = focusedWindow(in: application),
              let origin = accessibilityPoint(
                  of: window,
                  attribute: kAXPositionAttribute as CFString
              ),
              let size = accessibilitySize(
                  of: window,
                  attribute: kAXSizeAttribute as CFString
              ),
              size.width > 0,
              size.height > 0 else {
            return false
        }

        // Prompt composers in both supported apps occupy the lower center of
        // the content area. Multiple points cover compact, expanded and
        // response-in-progress layouts without moving the user's pointer.
        let candidates: [(x: CGFloat, y: CGFloat)] = [
            (0.50, 0.94),
            (0.58, 0.94),
            (0.50, 0.90),
            (0.58, 0.90),
            (0.50, 0.86)
        ]
        for candidate in candidates {
            let point = CGPoint(
                x: origin.x + size.width * candidate.x,
                y: origin.y + size.height * candidate.y
            )
            var hitElement: AXUIElement?
            guard AXUIElementCopyElementAtPosition(
                application,
                Float(point.x),
                Float(point.y),
                &hitElement
            ) == .success,
            let hitElement,
            let textArea = editableAncestor(startingAt: hitElement) else {
                continue
            }
            if AXUIElementSetAttributeValue(
                textArea,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            ) == .success {
                return true
            }
        }
        return false
    }

    private func focusedWindow(in application: AXUIElement) -> AXUIElement? {
        if let value = accessibilityValue(
            of: application,
            attribute: kAXFocusedWindowAttribute as CFString
        ), CFGetTypeID(value) == AXUIElementGetTypeID() {
            return unsafeDowncast(value, to: AXUIElement.self)
        }
        return (accessibilityValue(
            of: application,
            attribute: kAXWindowsAttribute as CFString
        ) as? [AXUIElement])?.first
    }

    private func editableAncestor(
        startingAt element: AXUIElement,
        maximumDepth: Int = 8
    ) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<maximumDepth {
            guard let candidate = current else { return nil }
            let role = accessibilityValue(
                of: candidate,
                attribute: kAXRoleAttribute as CFString
            ) as? String
            if role == (kAXTextAreaRole as String)
                || role == (kAXTextFieldRole as String) {
                var settable = DarwinBoolean(false)
                if AXUIElementIsAttributeSettable(
                    candidate,
                    kAXFocusedAttribute as CFString,
                    &settable
                ) == .success,
                settable.boolValue {
                    return candidate
                }
            }

            guard let parentValue = accessibilityValue(
                of: candidate,
                attribute: kAXParentAttribute as CFString
            ), CFGetTypeID(parentValue) == AXUIElementGetTypeID() else {
                return nil
            }
            current = unsafeDowncast(parentValue, to: AXUIElement.self)
        }
        return nil
    }

    private func accessibilityPoint(
        of element: AXUIElement,
        attribute: CFString
    ) -> CGPoint? {
        guard let value = accessibilityValue(of: element, attribute: attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(
            unsafeDowncast(value, to: AXValue.self),
            .cgPoint,
            &point
        ) else { return nil }
        return point
    }

    private func accessibilitySize(
        of element: AXUIElement,
        attribute: CFString
    ) -> CGSize? {
        guard let value = accessibilityValue(of: element, attribute: attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(
            unsafeDowncast(value, to: AXValue.self),
            .cgSize,
            &size
        ) else { return nil }
        return size
    }

    private func controlApplication(
        bundleIdentifier: String,
        operation: ApplicationActionOperation
    ) async -> ActionExecutionResult {
        switch operation {
        case .open:
            return await openApplication(bundleIdentifier: bundleIdentifier)
        case .close:
            let runningApplications = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            )
            guard !runningApplications.isEmpty else {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) == nil {
                    return .failure("未找到应用（\(bundleIdentifier)）")
                }
                return .failure("应用当前未运行")
            }
            guard runningApplications.allSatisfy({ $0.terminate() }) else {
                return .failure("无法退出应用")
            }
            return .success
        case .bringToFront:
            if let running = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first {
                return running.activate(options: [.activateAllWindows])
                    ? .success
                    : .failure("无法将应用置于前台")
            } else {
                return await openApplication(bundleIdentifier: bundleIdentifier)
            }
        }
    }

    private func openDefaultBrowser() -> ActionExecutionResult {
        openURL("https://www.google.com")
    }

    private func searchSelectedText() async -> ActionExecutionResult {
        guard AXIsProcessTrusted() else {
            return .failure("未获得辅助功能权限，无法读取所选文本")
        }
        guard let selection = await copySelectedText() else {
            return openDefaultBrowser()
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: selection)]
        guard let value = components?.url?.absoluteString else {
            return openDefaultBrowser()
        }
        return openURL(value)
    }

    private func openURLWithSelectedTextPrompt(
        url: String,
        instruction: String
    ) async -> ActionExecutionResult {
        guard AXIsProcessTrusted() else {
            return .failure("未获得辅助功能权限，无法读取所选文本")
        }
        guard let selection = await copySelectedText(),
              let prompt = SelectedTextPromptBuilder.prompt(
                instruction: instruction,
                selection: selection
              ) else {
            return openURL(url)
        }

        // Keep the composed prompt on the pasteboard as a reliable fallback.
        // The ChatGPT desktop app receives it directly; the browser URL also
        // carries it for web clients that support prefilled prompts.
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)

        let codexBundleIdentifier = ["com.openai.codex", "com.openai.chat"].first {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
        if let codexBundleIdentifier {
            if case let .failure(message) = await openApplication(
                bundleIdentifier: codexBundleIdentifier
            ) {
                return .failure(message)
            }
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(100))
                if NSRunningApplication
                    .runningApplications(withBundleIdentifier: codexBundleIdentifier)
                    .contains(where: { $0.isActive }) {
                    break
                }
            }
            return postKey(9, flags: .maskCommand)
                ? .success
                : .failure(eventPostingFailureMessage(for: "粘贴键盘事件"))
        }

        guard let destination = SelectedTextPromptBuilder.destinationURL(
            baseURL: url,
            prompt: prompt
        ) else {
            return openURL(url)
        }
        return NSWorkspace.shared.open(destination)
            ? .success
            : .failure("无法打开目标网址")
    }

    /// Starts the system dictation command in the active application without
    /// synthesizing the user's Globe/fn shortcut. This keeps remote voice input
    /// independent from whatever action macOS has assigned to Globe/fn.
    private func startDictation() async -> ActionExecutionResult {
        if let application = NSWorkspace.shared.frontmostApplication,
           application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
           pressMenuItem(withCommandGlyph: 150, in: application.processIdentifier) {
            return .success
        }

        // Accessibility can be unavailable briefly while an application is
        // launching. Fall back to the standard double-fn gesture so dictation
        // still works on machines that have not granted Accessibility yet.
        guard postKey(63, flags: .maskSecondaryFn) else {
            return .failure(eventPostingFailureMessage(for: "听写快捷键事件"))
        }
        do {
            try await Task.sleep(for: .milliseconds(90))
        } catch {
            return .failure("动作已取消")
        }
        return postKey(63, flags: .maskSecondaryFn)
            ? .success
            : .failure(eventPostingFailureMessage(for: "听写快捷键事件"))
    }

    private func pressMenuItem(withCommandGlyph glyph: Int, in processIdentifier: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(processIdentifier)
        guard let menuBarValue = accessibilityValue(
            of: application,
            attribute: kAXMenuBarAttribute as CFString
        ), CFGetTypeID(menuBarValue) == AXUIElementGetTypeID() else {
            return false
        }
        let menuBar = unsafeDowncast(menuBarValue, to: AXUIElement.self)
        guard
        let menuItem = descendantMenuItem(in: menuBar, commandGlyph: glyph, remainingDepth: 6) else {
            return false
        }
        return AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
    }

    private func descendantMenuItem(
        in element: AXUIElement,
        commandGlyph: Int,
        remainingDepth: Int
    ) -> AXUIElement? {
        if let value = accessibilityValue(
            of: element,
            attribute: kAXMenuItemCmdGlyphAttribute as CFString
        ) as? NSNumber,
        value.intValue == commandGlyph {
            return element
        }
        guard remainingDepth > 0,
              let children = accessibilityValue(
                of: element,
                attribute: kAXChildrenAttribute as CFString
              ) as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let match = descendantMenuItem(
                in: child,
                commandGlyph: commandGlyph,
                remainingDepth: remainingDepth - 1
            ) {
                return match
            }
        }
        return nil
    }

    private func accessibilityValue(
        of element: AXUIElement,
        attribute: CFString
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }

    private func copySelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        guard postKey(8, flags: .maskCommand) else { return nil }

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

    private func openURL(_ value: String) -> ActionExecutionResult {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return .failure("网址无效：\(value)")
        }
        return NSWorkspace.shared.open(url)
            ? .success
            : .failure("无法打开网址：\(value)")
    }

    private func launchProcess(path: String, arguments: [String]) -> ActionExecutionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
            return .success
        } catch {
            return .failure("无法启动系统进程：\(error.localizedDescription)")
        }
    }
}
