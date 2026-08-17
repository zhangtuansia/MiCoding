import Foundation

let miCodingSyntheticEventMarker: Int64 = 0x4D_69_43_6F_64_69_6E_67

enum RemotePhysicalKey: String, CaseIterable, Codable, Sendable {
    case power
    case voice
    case up
    case down
    case left
    case right
    case ok
    case back
    case home
    case menu
    case tv
    case volumeUp
    case volumeDown

    static let usageMap: [UInt32: RemotePhysicalKey] = [
        0x66: .power,
        0x3E: .voice,
        0x52: .up,
        0x51: .down,
        0x50: .left,
        0x4F: .right,
        0x28: .ok,
        0xF1: .back,
        0x4A: .home,
        0x65: .menu,
        0x35: .tv,
        0x80: .volumeUp,
        0x81: .volumeDown
    ]

    var slotID: String {
        rawValue
    }
}

enum RemoteTrigger: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case tap
    case hold
    case doubleTap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: "单击"
        case .hold: "长按"
        case .doubleTap: "双击"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随操作系统主题"
        case .light: "浅色主题"
        case .dark: "深色主题"
        }
    }
}

enum ActionsRingSize: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "小"
        case .medium: "中（默认）"
        case .large: "大"
        }
    }
}

struct ResolvedRemoteTrigger: Sendable {
    let slotID: String
    let trigger: RemoteTrigger
}

enum SystemActionName: String, Codable, Sendable {
    case spotlight
    case missionControl
    case showDesktop
    case lockScreen
    case screenshotRegion
    case playPause
    case previousTrack
    case nextTrack
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
}

enum ApplicationActionOperation: String, Codable, CaseIterable, Equatable, Sendable {
    case open
    case close
    case bringToFront

    var title: String {
        switch self {
        case .open: "打开"
        case .close: "关闭"
        case .bringToFront: "置于前台"
        }
    }
}

indirect enum ActionCommand: Codable, Equatable, Sendable {
    case keyStroke(keyCode: UInt16, flags: UInt64)
    case system(SystemActionName)
    case openApplication(bundleIdentifier: String)
    case openApplicationAtPath(String)
    case focusApplicationInput(bundleIdentifier: String)
    case controlApplication(bundleIdentifier: String, operation: ApplicationActionOperation)
    case openURL(String)
    case openDefaultBrowser
    case searchSelectedText
    case openURLWithSelectedTextPrompt(url: String, instruction: String)
    case typeText(String)
    case delay(milliseconds: Int)
    case startDictation
    case hardwareKeyPassThrough
    case showActionsRing
    case sequence([ActionCommand])
    case none

    static func command(for actionID: String) -> ActionCommand {
        switch actionID {
        case "show-actions-ring": .showActionsRing
        // Folder actions are intercepted by the Actions Ring overlay and open
        // a child ring. Keep a non-`.none` sentinel so catalog validation still
        // treats the folder as an intentional, executable UI action.
        case "actions-ring-folder-work": .sequence([])
        case "mission-control": .system(.missionControl)
        case "spotlight": .system(.spotlight)
        case "play-pause": .system(.playPause)
        case "previous-track": .system(.previousTrack)
        case "next-track": .system(.nextTrack)
        case "volume-up": .system(.volumeUp)
        case "volume-down": .system(.volumeDown)
        case "volume-adjust": .system(.volumeUp)
        case "brightness-adjust", "brightness-up": .system(.brightnessUp)
        case "brightness-down": .system(.brightnessDown)
        case "mute": .system(.mute)
        case "desktop": .system(.showDesktop)
        case "lock": .system(.lockScreen)
        case "screenshot": .system(.screenshotRegion)
        case "emoji-picker": .keyStroke(
            keyCode: 49,
            flags: UInt64((1 << 20) | (1 << 18))
        )
        case "copy": .keyStroke(keyCode: 8, flags: UInt64(1 << 20))
        case "paste": .keyStroke(keyCode: 9, flags: UInt64(1 << 20))
        case "cut": .keyStroke(keyCode: 7, flags: UInt64(1 << 20))
        case "undo": .keyStroke(keyCode: 6, flags: UInt64(1 << 20))
        case "keyboard-shortcut": .keyStroke(keyCode: 40, flags: UInt64(1 << 20))
        case "arrow-up": .keyStroke(keyCode: 126, flags: 0)
        case "arrow-down": .keyStroke(keyCode: 125, flags: 0)
        case "arrow-left": .keyStroke(keyCode: 123, flags: 0)
        case "arrow-right": .keyStroke(keyCode: 124, flags: 0)
        case "redo": .keyStroke(keyCode: 6, flags: UInt64((1 << 20) | (1 << 17)))
        case "select-all": .keyStroke(keyCode: 0, flags: UInt64(1 << 20))
        case "enter": .keyStroke(keyCode: 36, flags: 0)
        case "escape": .keyStroke(keyCode: 53, flags: 0)
        case "delete": .keyStroke(keyCode: 51, flags: 0)
        case "browser-back": .keyStroke(keyCode: 33, flags: UInt64(1 << 20))
        case "browser-forward": .keyStroke(keyCode: 30, flags: UInt64(1 << 20))
        case "launch-browser": .openDefaultBrowser
        case "launch-music": .openApplication(bundleIdentifier: "com.apple.Music")
        case "launch-finder": .openApplication(bundleIdentifier: "com.apple.finder")
        case "launch-calendar": .openApplication(bundleIdentifier: "com.apple.iCal")
        case "launch-notes": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Notes"),
            .delay(milliseconds: 450),
            .keyStroke(keyCode: 45, flags: UInt64(1 << 20))
        ])
        case "explore-ai": .openURL("https://chatgpt.com")
        case "launch-micoding": .openApplication(bundleIdentifier: "io.xiaomiremote.studio")
        case "open-codex": .sequence([
            .openApplication(bundleIdentifier: "com.openai.codex"),
            .focusApplicationInput(bundleIdentifier: "com.openai.codex")
        ])
        case "open-claude": .sequence([
            .openApplication(bundleIdentifier: "com.anthropic.claudefordesktop"),
            .focusApplicationInput(bundleIdentifier: "com.anthropic.claudefordesktop")
        ])
        case "start-dictation": .startDictation
        case "typeless-dictation": .hardwareKeyPassThrough
        case "voice-codex": .sequence([
            .openApplication(bundleIdentifier: "com.openai.codex"),
            .focusApplicationInput(bundleIdentifier: "com.openai.codex"),
            .startDictation
        ])
        case "voice-claude": .sequence([
            .openApplication(bundleIdentifier: "com.anthropic.claudefordesktop"),
            .focusApplicationInput(bundleIdentifier: "com.anthropic.claudefordesktop"),
            .startDictation
        ])
        case "ai-submit": .keyStroke(keyCode: 36, flags: 0)
        case "ai-newline": .keyStroke(keyCode: 36, flags: UInt64(1 << 17))
        case "ai-cancel": .keyStroke(keyCode: 53, flags: 0)
        case "ai-attach-file": .keyStroke(keyCode: 31, flags: UInt64(1 << 20))
        case "codex-new-chat", "claude-new-conversation": .keyStroke(
            keyCode: 45,
            flags: UInt64(1 << 20)
        )
        case "codex-open-terminal": .keyStroke(keyCode: 50, flags: UInt64(1 << 18))
        case "codex-toggle-file-tree": .keyStroke(
            keyCode: 14,
            flags: UInt64((1 << 20) | (1 << 17))
        )
        case "codex-toggle-review": .keyStroke(
            keyCode: 11,
            flags: UInt64((1 << 20) | (1 << 19))
        )
        case "codex-previous-chat": .keyStroke(
            keyCode: 33,
            flags: UInt64((1 << 20) | (1 << 17))
        )
        case "codex-next-chat": .keyStroke(
            keyCode: 30,
            flags: UInt64((1 << 20) | (1 << 17))
        )
        case "smart-focus": .sequence([
            .openApplication(bundleIdentifier: "com.apple.iCal"),
            .openApplication(bundleIdentifier: "com.apple.Notes"),
            .openDefaultBrowser
        ])
        case "smart-meeting": .sequence([
            .openApplication(bundleIdentifier: "com.apple.iCal"),
            .delay(milliseconds: 450),
            .openApplication(bundleIdentifier: "com.apple.FaceTime"),
            .delay(milliseconds: 450),
            .system(.mute)
        ])
        case "smart-note": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Music"),
            .openURL("https://www.youtube.com")
        ])
        case "smart-netflix": .sequence([
            .openURL("https://www.netflix.com")
        ])
        case "smart-google-work": .sequence([
            .openURL("https://mail.google.com"),
            .openURL("https://drive.google.com"),
            .openURL("https://calendar.google.com")
        ])
        case "smart-microsoft-work": .sequence([
            .openURL("https://outlook.office.com"),
            .openURL("https://teams.microsoft.com"),
            .openURL("https://onedrive.live.com")
        ])
        case "smart-browser": .sequence([
            .openDefaultBrowser
        ])
        case "smart-screenshot": .sequence([
            .system(.screenshotRegion)
        ])
        case "smart-notes-app": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Notes")
        ])
        case "smart-ai-work": .sequence([
            .openURL("https://chatgpt.com")
        ])
        case "smart-web-search": .sequence([
            .searchSelectedText
        ])
        case "smart-break": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Music"),
            .openURL("https://www.youtube.com")
        ])
        case "smart-flights": .sequence([
            .openURL("https://www.google.com/travel/flights")
        ])
        case "smart-shopping": .sequence([
            .openURL("https://shopping.google.com")
        ])
        case "smart-perplexity": .sequence([
            .openURL("https://www.perplexity.ai")
        ])
        case "smart-firefly": .sequence([
            .openURL("https://firefly.adobe.com")
        ])
        case "smart-copilot": .sequence([
            .openURL("https://copilot.microsoft.com")
        ])
        case "smart-gemini": .sequence([
            .openURL("https://gemini.google.com")
        ])
        case "smart-ai-reply": .sequence([
            .openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请根据以下消息起草一份简洁、自然的回复："
            )
        ])
        case "smart-ai-grammar": .sequence([
            .openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请检查并改正以下文本的语法和表达，只返回修改后的文本："
            )
        ])
        case "smart-ai-summary": .sequence([
            .openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请用要点总结以下文本："
            )
        ])
        case "smart-ai-translate": .sequence([
            .openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请将以下文本翻译成英语，保持原意和语气："
            )
        ])
        case "smart-ai-code": .sequence([
            .openURLWithSelectedTextPrompt(
                url: "https://chatgpt.com",
                instruction: "请解释以下代码的作用、关键逻辑和潜在问题："
            )
        ])
        case "smart-morning": .sequence([
            .openApplication(bundleIdentifier: "com.apple.iCal"),
            .openApplication(bundleIdentifier: "com.apple.Notes"),
            .openDefaultBrowser
        ])
        case "smart-sports": .sequence([
            .openURL("https://www.google.com/search?q=live+sports+scores")
        ])
        case "smart-github": .sequence([
            .openURL("https://github.com")
        ])
        case "smart-developer-docs": .sequence([
            .openURL("https://developer.apple.com/documentation")
        ])
        default: .none
        }
    }
}

enum SelectedTextPromptBuilder {
    static func prompt(
        instruction: String,
        selection: String,
        maxSelectionCharacters: Int = 6_000
    ) -> String? {
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruction.isEmpty,
              !trimmedSelection.isEmpty,
              maxSelectionCharacters > 0 else {
            return nil
        }

        let clippedSelection = String(trimmedSelection.prefix(maxSelectionCharacters))
        return "\(trimmedInstruction)\n\n\(clippedSelection)"
    }

    static func destinationURL(baseURL: String, prompt: String) -> URL? {
        guard var components = URLComponents(string: baseURL),
              ["http", "https"].contains(components.scheme?.lowercased()),
              !prompt.isEmpty else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "q" }
        queryItems.append(URLQueryItem(name: "q", value: prompt))
        components.queryItems = queryItems
        return components.url
    }
}

enum SmartActionStep: Codable, Equatable, Sendable {
    case action(String)
    // Kept for backward-compatible decoding of workflows created before
    // application operations were configurable. It is equivalent to `.open`.
    case application(bundleIdentifier: String, name: String)
    /// Opens the exact application bundle selected by the user. Keeping the
    /// path alongside the display name also supports unsigned/local `.app`
    /// bundles that do not publish a usable bundle identifier.
    case applicationPath(path: String, name: String)
    case applicationControl(
        bundleIdentifier: String,
        name: String,
        operation: ApplicationActionOperation
    )
    case keystroke(keyCode: UInt16, flags: UInt64, name: String)
    case text(String)
    case url(String)
    case delay(milliseconds: Int)

    var command: ActionCommand {
        return switch self {
        case let .action(actionID):
            ActionCommand.command(for: actionID)
        case let .application(bundleIdentifier, name):
            Self.hasValidApplicationFields(bundleIdentifier: bundleIdentifier, name: name)
                ? .openApplication(bundleIdentifier: bundleIdentifier)
                : .none
        case let .applicationPath(path, name):
            Self.hasValidApplicationPath(path: path, name: name)
                ? .openApplicationAtPath(path)
                : .none
        case let .applicationControl(bundleIdentifier, name, operation):
            Self.hasValidApplicationFields(bundleIdentifier: bundleIdentifier, name: name)
                ? .controlApplication(bundleIdentifier: bundleIdentifier, operation: operation)
                : .none
        case let .keystroke(keyCode, flags, name):
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .none
                : .keyStroke(keyCode: keyCode, flags: flags)
        case let .text(value):
            value.isEmpty || value.count > 1_000 ? .none : .typeText(value)
        case let .url(value):
            Self.normalizedWebURL(value).map(ActionCommand.openURL) ?? .none
        case let .delay(milliseconds):
            (100...99_999).contains(milliseconds)
                ? .delay(milliseconds: milliseconds)
                : .none
        }
    }

    var isValid: Bool {
        command != .none
    }

    var legacyActionID: String? {
        guard case let .action(actionID) = self else { return nil }
        return actionID
    }

    private static func hasValidApplicationFields(
        bundleIdentifier: String,
        name: String
    ) -> Bool {
        !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func hasValidApplicationPath(path: String, name: String) -> Bool {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedPath.hasPrefix("/")
            && URL(fileURLWithPath: normalizedPath).pathExtension
                .localizedCaseInsensitiveCompare("app") == .orderedSame
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizedWebURL(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return normalized
    }
}

enum SmartActionTrigger: Codable, Equatable, Sendable {
    case application(bundleIdentifier: String, name: String)
    case device
    case actionsRing
    case shortcut(keyCode: UInt16, flags: UInt64, name: String)

    private static let supportedModifierMask = UInt64(
        (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 23)
    )

    var isValid: Bool {
        switch self {
        case let .application(bundleIdentifier, name):
            !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .device:
            true
        case .actionsRing:
            true
        case let .shortcut(_, flags, name):
            flags & Self.supportedModifierMask != 0 && !name.isEmpty
        }
    }

}

struct GlobalShortcutBinding: Equatable, Sendable {
    let actionID: String
    let keyCode: UInt16
    let flags: UInt64
}

struct ApplicationTriggerBinding: Equatable, Sendable {
    let actionID: String
    let bundleIdentifier: String
}

struct BackendSettings: Codable, Equatable, Sendable {
    var holdMilliseconds = 350
    var doubleTapMilliseconds = 250
    var debounceMilliseconds: Int?
    var remoteVendorID = 0x2717
    var remoteProductID = 0x32B8
}

struct PersistedSmartAction: Codable, Equatable, Sendable {
    let id: String
    let actionID: String
    let title: String
    let stepActionIDs: [String]?
    let steps: [SmartActionStep]?
    let triggers: [SmartActionTrigger]?
    let isEnabled: Bool?

    init(
        id: String,
        actionID: String,
        title: String,
        stepActionIDs: [String]? = nil,
        steps: [SmartActionStep]? = nil,
        triggers: [SmartActionTrigger]? = nil,
        isEnabled: Bool? = nil
    ) {
        self.id = id
        self.actionID = actionID
        self.title = title
        self.stepActionIDs = stepActionIDs
        self.steps = steps
        self.triggers = triggers
        self.isEnabled = isEnabled
    }
}

struct PersistedConfiguration: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var settings = BackendSettings()
    var assignmentsByProfile: [String: [String: String]]
    var holdAssignmentsByProfile: [String: [String: String]] = [:]
    var doubleTapAssignmentsByProfile: [String: [String: String]] = [:]
    var lastProfileID = "global"
    var useDarkAppearance = false
    var appearanceMode: AppAppearanceMode?
    var automaticUpdatesEnabled: Bool?
    var remoteIsManaged: Bool?
    var inputServiceEnabled: Bool?
    var showActionNotifications: Bool?
    var showPermissionReminders: Bool?
    var showExperienceRecommendations: Bool?
    var showConnectionNotifications: Bool?
    var showLowBatteryNotifications: Bool?
    var customSmartActions: [PersistedSmartAction]?
    var removedProfileIDs: [String]?
    var actionsRingActionIDs: [String]?
    var actionsRingSize: ActionsRingSize?
    var actionsRingAssignmentsByProfile: [String: [String]]?
    var lastActionsRingProfileID: String?
}

struct DeviceConfigurationBackup: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var deviceID: String
    var exportedAt: Date
    var configuration: PersistedConfiguration
}

enum DeviceConfigurationBackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case unsupportedConfigurationVersion(Int)
    case incompatibleDevice(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "无法读取版本为 \(version) 的设备备份"
        case let .unsupportedConfigurationVersion(version):
            "此备份包含不受支持的配置版本 \(version)"
        case let .incompatibleDevice(deviceID):
            "此备份属于其他设备（\(deviceID)）"
        }
    }
}
