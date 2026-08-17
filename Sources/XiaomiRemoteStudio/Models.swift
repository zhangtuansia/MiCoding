import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case devices
    case automations
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: "设备"
        case .automations: "智能操作"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .devices: "av.remote"
        case .automations: "bolt.horizontal.circle"
        case .settings: "gearshape"
        }
    }
}

enum DeviceConnectionState: Equatable {
    case connected
    case connecting
    case disconnected

    var title: String {
        switch self {
        case .connected: "已连接"
        case .connecting: "正在连接"
        case .disconnected: "未连接"
        }
    }

    var color: Color {
        switch self {
        case .connected: Color(red: 0.15, green: 0.72, blue: 0.48)
        case .connecting: Color.orange
        case .disconnected: Color.secondary
        }
    }
}

struct RemoteDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let model: String
    let slotCount: Int

    static let remote2Pro = RemoteDevice(
        id: "xiaomi-remote-2-pro",
        name: "Xiaomi Remote 2 Pro",
        model: "蓝牙遥控器",
        slotCount: RemoteButtonSlot.demoSlots.count
    )
}

enum RemoteButtonShape: String, Hashable {
    case circle
    case roundedSquare
    case capsuleVertical
    case dpadUp
    case dpadLeft
    case dpadRight
    case dpadDown
    case rockerTop
    case rockerBottom
}

struct RemoteButtonSlot: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let shape: RemoteButtonShape
    let allowedCategories: Set<ActionCategory>

    func accepts(_ action: RemoteAction, trigger: RemoteTrigger = .tap) -> Bool {
        action.isEligible(for: .remoteButton(slotID: id, trigger: trigger))
            && (allowedCategories.isEmpty
                || action.category == .recommended
                || allowedCategories.contains(action.category))
    }

    static let demoSlots: [RemoteButtonSlot] = [
        .init(id: "power", name: "电源", symbol: "power", x: 0.295, y: 0.110, width: 0.19, height: 0.055, shape: .circle, allowedCategories: [.system, .apps, .shortcut]),
        .init(id: "voice", name: "语音", symbol: "mic.fill", x: 0.705, y: 0.110, width: 0.19, height: 0.055, shape: .circle, allowedCategories: [.system, .apps, .shortcut]),
        .init(id: "up", name: "上", symbol: "chevron.up", x: 0.50, y: 0.257, width: 0.659, height: 0.188, shape: .dpadUp, allowedCategories: [.system, .media, .shortcut]),
        .init(id: "left", name: "左", symbol: "chevron.left", x: 0.50, y: 0.257, width: 0.659, height: 0.188, shape: .dpadLeft, allowedCategories: [.system, .media, .shortcut]),
        .init(id: "ok", name: "确认", symbol: "circle.fill", x: 0.50, y: 0.257, width: 0.333, height: 0.090, shape: .circle, allowedCategories: []),
        .init(id: "right", name: "右", symbol: "chevron.right", x: 0.50, y: 0.257, width: 0.659, height: 0.188, shape: .dpadRight, allowedCategories: [.system, .media, .shortcut]),
        .init(id: "down", name: "下", symbol: "chevron.down", x: 0.50, y: 0.257, width: 0.659, height: 0.188, shape: .dpadDown, allowedCategories: [.system, .media, .shortcut]),
        .init(id: "back", name: "返回", symbol: "arrow.uturn.backward", x: 0.331, y: 0.400, width: 0.263, height: 0.076, shape: .circle, allowedCategories: []),
        .init(id: "home", name: "主页", symbol: "house.fill", x: 0.331, y: 0.488, width: 0.263, height: 0.076, shape: .circle, allowedCategories: []),
        .init(id: "menu", name: "菜单", symbol: "line.3.horizontal", x: 0.331, y: 0.578, width: 0.263, height: 0.076, shape: .circle, allowedCategories: []),
        .init(id: "volumeUp", name: "音量增加", symbol: "plus", x: 0.668, y: 0.444, width: 0.265, height: 0.163, shape: .rockerTop, allowedCategories: [.media, .system, .shortcut]),
        .init(id: "volumeDown", name: "音量减少", symbol: "minus", x: 0.668, y: 0.444, width: 0.265, height: 0.163, shape: .rockerBottom, allowedCategories: [.media, .system, .shortcut]),
        .init(id: "tv", name: "电视", symbol: "tv.fill", x: 0.668, y: 0.578, width: 0.265, height: 0.076, shape: .circle, allowedCategories: [.system, .media, .apps, .shortcut])
    ]
}

enum ActionCategory: String, CaseIterable, Identifiable, Hashable {
    case recommended
    case system
    case media
    case apps
    case shortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: "推荐"
        case .system: "系统"
        case .media: "媒体"
        case .apps: "应用"
        case .shortcut: "快捷键"
        }
    }
}

enum RemoteActionPlacement: Equatable {
    case remoteButton(slotID: String, trigger: RemoteTrigger)
    case actionsRing
    case smartActionStep
}

enum RemoteActionEligibility: Hashable {
    /// The action can be used anywhere, subject to the target button's
    /// category restrictions.
    case standard
    /// Folder actions are navigation nodes owned by the Actions Ring runtime,
    /// not executable commands that can be assigned elsewhere.
    case actionsRingOnly
    /// Hardware passthrough is meaningful only for the physical voice key's
    /// primary press. Using it elsewhere would consume input without an action.
    case voiceButtonTapOnly

    func permits(_ placement: RemoteActionPlacement) -> Bool {
        switch (self, placement) {
        case (.standard, _), (.actionsRingOnly, .actionsRing):
            true
        case let (.voiceButtonTapOnly, .remoteButton(slotID: slotID, trigger: .tap)):
            slotID == RemotePhysicalKey.voice.slotID
        default:
            false
        }
    }
}

struct RemoteAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let category: ActionCategory
    let tint: Color
    let eligibility: RemoteActionEligibility

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        category: ActionCategory,
        tint: Color,
        eligibility: RemoteActionEligibility = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.category = category
        self.tint = tint
        self.eligibility = eligibility
    }

    func isEligible(for placement: RemoteActionPlacement) -> Bool {
        eligibility.permits(placement)
    }

    var actionsRingParameterKind: ActionsRingParameterKind? {
        switch id {
        case "volume-adjust": .volume
        case "brightness-adjust": .brightness
        default: nil
        }
    }

    /// Device configuration is shown in the active Chinese UI, while the
    /// Actions Ring editor intentionally preserves several reference action
    /// names such as "Lock Workstation" and "New Note". Keep the stable model
    /// title for that editor and localize only the device-facing presentation.
    var devicePresentationTitle: String {
        switch id {
        case "lock": "锁定屏幕"
        case "screenshot": "区域截图"
        case "emoji-picker": "表情与符号"
        case "launch-notes": "新建备忘录"
        case "explore-ai": "探索 AI"
        case "launch-micoding": "打开 MiCoding"
        case "open-codex": "打开 Codex"
        case "open-claude": "打开 Claude"
        case "start-dictation": "开始语音输入"
        case "typeless-dictation": "Typeless 语音输入"
        default: title
        }
    }

    static let catalog: [RemoteAction] = [
        .init(id: "show-actions-ring", title: "显示 Actions Ring", subtitle: "在指针位置打开快捷动作环", symbol: "circle-dot", category: .recommended, tint: .purple),
        .init(id: "actions-ring-folder-work", title: "工作模式", subtitle: "文件夹 · 9 个常用工作操作", symbol: "folder.fill", category: .recommended, tint: .purple, eligibility: .actionsRingOnly),
        .init(id: "mission-control", title: "调度中心", subtitle: "查看所有窗口", symbol: "rectangle.3.group", category: .recommended, tint: .purple),
        .init(id: "spotlight", title: "Spotlight 效果", subtitle: "快速查找内容", symbol: "magnifyingglass", category: .recommended, tint: .indigo),
        .init(id: "copy", title: "复制", subtitle: "复制所选内容", symbol: "doc.on.doc", category: .recommended, tint: .blue),
        .init(id: "paste", title: "粘贴", subtitle: "粘贴剪贴板内容", symbol: "clipboard", category: .recommended, tint: .green),
        .init(id: "undo", title: "撤销", subtitle: "撤销上一步操作", symbol: "arrow.uturn.backward.circle", category: .recommended, tint: .orange),
        .init(id: "keyboard-shortcut", title: "键盘快捷键", subtitle: "发送常用的 ⌘K 快捷键", symbol: "keyboard", category: .recommended, tint: .gray),
        .init(id: "arrow-up", title: "向上", subtitle: "发送键盘上方向键", symbol: "chevron.up", category: .system, tint: .gray),
        .init(id: "arrow-down", title: "向下", subtitle: "发送键盘下方向键", symbol: "chevron.down", category: .system, tint: .gray),
        .init(id: "arrow-left", title: "向左", subtitle: "发送键盘左方向键", symbol: "chevron.left", category: .system, tint: .gray),
        .init(id: "arrow-right", title: "向右", subtitle: "发送键盘右方向键", symbol: "chevron.right", category: .system, tint: .gray),
        .init(id: "redo", title: "重做", subtitle: "恢复上一步操作", symbol: "arrow.uturn.forward.circle", category: .system, tint: .orange),
        .init(id: "cut", title: "剪切", subtitle: "剪切所选内容", symbol: "scissors", category: .system, tint: .red),
        .init(id: "select-all", title: "全选", subtitle: "选择当前范围全部内容", symbol: "textformat", category: .system, tint: .indigo),
        .init(id: "enter", title: "回车", subtitle: "发送 Return 按键", symbol: "return", category: .system, tint: .gray),
        .init(id: "escape", title: "退出 / Escape", subtitle: "关闭菜单或取消当前操作", symbol: "escape", category: .system, tint: .gray),
        .init(id: "delete", title: "删除", subtitle: "发送 Delete 按键", symbol: "delete.left", category: .system, tint: .red),
        .init(id: "play-pause", title: "播放/暂停", subtitle: "控制当前媒体", symbol: "playpause.fill", category: .media, tint: .pink),
        .init(id: "volume-adjust", title: "调节音量", subtitle: "Actions Ring 参数气泡 · 滚动或左右拖动", symbol: "sliders-horizontal", category: .media, tint: .purple),
        .init(id: "previous-track", title: "上一首", subtitle: "返回上一媒体", symbol: "backward.end.fill", category: .media, tint: .orange),
        .init(id: "next-track", title: "下一首", subtitle: "跳到下一媒体", symbol: "forward.end.fill", category: .media, tint: .orange),
        .init(id: "volume-up", title: "音量增加", subtitle: "系统音量 +5%", symbol: "speaker.plus.fill", category: .media, tint: .blue),
        .init(id: "volume-down", title: "音量降低", subtitle: "系统音量 -5%", symbol: "speaker.minus.fill", category: .media, tint: .blue),
        .init(id: "mute", title: "静音", subtitle: "切换系统静音", symbol: "speaker.slash.fill", category: .media, tint: .red),
        .init(id: "desktop", title: "显示桌面", subtitle: "隐藏全部窗口", symbol: "macwindow", category: .system, tint: .teal),
        .init(id: "brightness-adjust", title: "调节亮度", subtitle: "Actions Ring 参数气泡 · 滚动或左右拖动", symbol: "sun", category: .system, tint: .yellow),
        .init(id: "lock", title: "Lock Workstation", subtitle: "立即锁定 Mac", symbol: "lock.fill", category: .system, tint: .gray),
        .init(id: "screenshot", title: "Screenshot", subtitle: "选择区域并截图", symbol: "viewfinder", category: .system, tint: .green),
        .init(id: "emoji-picker", title: "Emoji", subtitle: "打开表情与符号面板", symbol: "smile", category: .system, tint: .yellow),
        .init(id: "browser-back", title: "后退", subtitle: "浏览器或 Finder 返回上一页", symbol: "arrow.left", category: .system, tint: .purple),
        .init(id: "browser-forward", title: "前进", subtitle: "浏览器或 Finder 前往下一页", symbol: "arrow.right", category: .system, tint: .purple),
        .init(id: "launch-browser", title: "打开浏览器", subtitle: "启动默认浏览器", symbol: "safari.fill", category: .apps, tint: .blue),
        .init(id: "launch-music", title: "打开音乐", subtitle: "启动音乐应用", symbol: "music.note", category: .apps, tint: .pink),
        .init(id: "launch-finder", title: "Finder", subtitle: "启动文件管理器", symbol: "folder.fill", category: .apps, tint: .blue),
        .init(id: "launch-calendar", title: "打开日历", subtitle: "启动日历应用", symbol: "calendar", category: .apps, tint: .red),
        .init(id: "launch-notes", title: "New Note", subtitle: "在备忘录中创建空白笔记", symbol: "square.and.pencil", category: .apps, tint: .yellow),
        .init(id: "explore-ai", title: "Explore AI", subtitle: "打开 AI 助手", symbol: "sparkles", category: .recommended, tint: .purple),
        .init(id: "launch-micoding", title: "MiCoding App", subtitle: "将 MiCoding 置于前台", symbol: "mouse", category: .apps, tint: .purple),
        .init(id: "open-codex", title: "打开 Codex", subtitle: "置于前台并聚焦输入框", symbol: "terminal", category: .apps, tint: .blue),
        .init(id: "open-claude", title: "打开 Claude", subtitle: "置于前台并聚焦输入框", symbol: "sparkles", category: .apps, tint: .orange),
        .init(id: "start-dictation", title: "开始语音输入", subtitle: "直接启动当前应用的系统听写", symbol: "mic.fill", category: .recommended, tint: .purple),
        .init(id: "typeless-dictation", title: "Typeless 语音输入", subtitle: "遥控器语音键专用 · 硬件 F20", symbol: "mic.fill", category: .recommended, tint: .purple, eligibility: .voiceButtonTapOnly),
        .init(id: "voice-codex", title: "语音问 Codex", subtitle: "打开 Codex 并启动系统听写", symbol: "mic.fill", category: .recommended, tint: .blue),
        .init(id: "voice-claude", title: "语音问 Claude", subtitle: "打开 Claude 并启动系统听写", symbol: "mic.fill", category: .recommended, tint: .orange),
        .init(id: "ai-submit", title: "发送给 AI", subtitle: "发送当前提示词", symbol: "return", category: .recommended, tint: .green),
        .init(id: "ai-newline", title: "AI 换行", subtitle: "在提示词中插入新行", symbol: "return", category: .shortcut, tint: .gray),
        .init(id: "ai-cancel", title: "取消 / 停止", subtitle: "取消弹窗或停止当前操作", symbol: "escape", category: .recommended, tint: .red),
        .init(id: "ai-attach-file", title: "添加文件", subtitle: "打开 AI 应用的文件选择器", symbol: "paperclip", category: .shortcut, tint: .indigo),
        .init(id: "codex-new-chat", title: "Codex 新任务", subtitle: "新建 Codex 对话", symbol: "square.and.pencil", category: .shortcut, tint: .blue),
        .init(id: "claude-new-conversation", title: "Claude 新对话", subtitle: "新建 Claude 对话", symbol: "square.and.pencil", category: .shortcut, tint: .orange),
        .init(id: "codex-open-terminal", title: "Codex 终端", subtitle: "打开或关闭 Codex 终端", symbol: "terminal", category: .shortcut, tint: .gray),
        .init(id: "codex-toggle-file-tree", title: "Codex 文件树", subtitle: "打开或关闭文件树", symbol: "folder", category: .shortcut, tint: .blue),
        .init(id: "codex-toggle-review", title: "Codex 审查", subtitle: "打开或关闭代码审查", symbol: "magnifyingglass", category: .shortcut, tint: .purple),
        .init(id: "codex-previous-chat", title: "上一个 Codex 任务", subtitle: "切换到上一个任务", symbol: "chevron.left", category: .shortcut, tint: .blue),
        .init(id: "codex-next-chat", title: "下一个 Codex 任务", subtitle: "切换到下一个任务", symbol: "chevron.right", category: .shortcut, tint: .blue),
        .init(id: "smart-focus", title: "办公模式", subtitle: "打开日历、备忘录和浏览器", symbol: "moon.stars.fill", category: .shortcut, tint: .indigo),
        .init(id: "smart-meeting", title: "会议模式", subtitle: "日历、FaceTime 与静音", symbol: "video.fill", category: .shortcut, tint: .blue),
        .init(id: "smart-note", title: "休憩时刻", subtitle: "打开音乐和 YouTube", symbol: "square.and.pencil", category: .shortcut, tint: .orange),
        .init(id: "smart-netflix", title: "Netflix 时间", subtitle: "打开 Netflix", symbol: "play.fill", category: .shortcut, tint: .red),
        .init(id: "smart-google-work", title: "办公模式 Google 套件", subtitle: "打开 Gmail、Google Drive 和日历", symbol: "globe", category: .shortcut, tint: .blue),
        .init(id: "smart-microsoft-work", title: "办公模式 MS 套件", subtitle: "打开 Outlook、Teams 和 OneDrive", symbol: "macwindow", category: .shortcut, tint: .indigo),
        .init(id: "smart-browser", title: "打开浏览器", subtitle: "立即打开默认浏览器", symbol: "safari.fill", category: .shortcut, tint: .blue),
        .init(id: "smart-screenshot", title: "快速截屏", subtitle: "截取当前屏幕并保存", symbol: "viewfinder", category: .shortcut, tint: .purple),
        .init(id: "smart-notes-app", title: "打开备忘录", subtitle: "立即打开备忘录应用", symbol: "note.text", category: .shortcut, tint: .yellow),
        .init(id: "smart-ai-work", title: "AI 工作台", subtitle: "打开 ChatGPT", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-web-search", title: "选择并搜索网络", subtitle: "复制所选文本并在网络上搜索", symbol: "magnifyingglass", category: .shortcut, tint: .blue),
        .init(id: "smart-break", title: "休息一下", subtitle: "打开音乐和 YouTube", symbol: "music.note", category: .shortcut, tint: .orange),
        .init(id: "smart-flights", title: "想去哪里？", subtitle: "探索下一次旅行的航班", symbol: "globe", category: .shortcut, tint: .blue),
        .init(id: "smart-shopping", title: "购物优惠", subtitle: "打开 Google 购物查找优惠", symbol: "globe", category: .shortcut, tint: .green),
        .init(id: "smart-perplexity", title: "问问 Perplexity", subtitle: "打开 Perplexity 开始搜索", symbol: "sparkles", category: .shortcut, tint: .indigo),
        .init(id: "smart-firefly", title: "Adobe Firefly", subtitle: "打开 Adobe Firefly 开始创作", symbol: "sparkles", category: .shortcut, tint: .orange),
        .init(id: "smart-copilot", title: "在浏览器上打开 Copilot", subtitle: "打开 Microsoft Copilot", symbol: "macwindow", category: .shortcut, tint: .blue),
        .init(id: "smart-gemini", title: "Google Gemini", subtitle: "打开 Gemini 询问任何问题", symbol: "sparkles", category: .shortcut, tint: .blue),
        .init(id: "smart-ai-reply", title: "AI 回复消息", subtitle: "用所选文本生成回复提示词", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-ai-grammar", title: "AI 纠正语法", subtitle: "用所选文本生成语法修改提示词", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-ai-summary", title: "AI 汇总文本", subtitle: "用所选文本生成要点摘要提示词", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-ai-translate", title: "AI 英语翻译", subtitle: "用所选文本生成英语翻译提示词", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-ai-code", title: "AI 代码解释", subtitle: "用所选代码生成解释提示词", symbol: "sparkles", category: .shortcut, tint: .purple),
        .init(id: "smart-morning", title: "清晨设置", subtitle: "打开日历、备忘录和浏览器", symbol: "calendar", category: .shortcut, tint: .yellow),
        .init(id: "smart-sports", title: "查看最新比分", subtitle: "打开实时体育比分搜索", symbol: "globe", category: .shortcut, tint: .green),
        .init(id: "smart-github", title: "打开 GitHub", subtitle: "打开 GitHub 工作台", symbol: "globe", category: .shortcut, tint: .gray),
        .init(id: "smart-developer-docs", title: "开发者文档", subtitle: "打开 Apple 开发者文档", symbol: "macwindow", category: .shortcut, tint: .blue)
    ]
}

enum ActionsRingParameterKind: String, CaseIterable, Hashable {
    case volume
    case brightness

    var title: String {
        switch self {
        case .volume: "音量"
        case .brightness: "亮度"
        }
    }
}

struct ActionsRingFolderDefinition: Identifiable, Hashable {
    let actionID: String
    let title: String
    let symbol: String
    let actionIDs: [String]

    var id: String { actionID }

    var actions: [RemoteAction] {
        actionIDs.compactMap { actionID in
            RemoteAction.catalog.first(where: { $0.id == actionID })
        }
    }
}

/// Built-in folders make the runtime ring useful beyond its eight primary
/// bubbles. The reference exposes nine supplementary sub-bubbles per folder;
/// keep these IDs stable so folder assignments survive future catalog changes.
enum ActionsRingFolderCatalog {
    static let definitions: [ActionsRingFolderDefinition] = [
        ActionsRingFolderDefinition(
            actionID: "actions-ring-folder-work",
            title: "工作模式",
            symbol: "folder.fill",
            actionIDs: [
                "launch-calendar",
                "launch-notes",
                "launch-finder",
                "launch-browser",
                "copy",
                "paste",
                "screenshot",
                "mission-control",
                "smart-focus"
            ]
        )
    ]

    static func definition(for actionID: String) -> ActionsRingFolderDefinition? {
        definitions.first(where: { $0.actionID == actionID })
    }
}

struct AppProfile: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let bundleIdentifier: String?

    static let profiles: [AppProfile] = [
        .init(id: "global", title: "所有应用", subtitle: "全局配置", symbol: "globe", tint: .purple, bundleIdentifier: nil),
        .init(id: "chrome", title: "Chrome", subtitle: "浏览网页", symbol: "globe", tint: .green, bundleIdentifier: "com.google.Chrome"),
        .init(id: "safari", title: "Safari", subtitle: "浏览网页", symbol: "safari.fill", tint: .blue, bundleIdentifier: "com.apple.Safari"),
        .init(
            id: "tencent-meeting",
            title: "Tencent Meeting",
            subtitle: "视频会议",
            symbol: "video.fill",
            tint: .blue,
            bundleIdentifier: "com.tencent.meeting"
        ),
        .init(
            id: "com.openai.codex",
            title: "Codex",
            subtitle: "AI 编程",
            symbol: "terminal",
            tint: .blue,
            bundleIdentifier: "com.openai.codex"
        ),
        .init(
            id: "com.anthropic.claudefordesktop",
            title: "Claude",
            subtitle: "AI 助手",
            symbol: "sparkles",
            tint: .orange,
            bundleIdentifier: "com.anthropic.claudefordesktop"
        )
    ]
}

struct SmartAction: Identifiable {
    let id: String
    let actionID: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let stepCount: Int
    let steps: [SmartActionStep]?
    let triggers: [SmartActionTrigger]?
    let isEnabled: Bool

    init(
        id: String,
        actionID: String,
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        stepCount: Int,
        stepActionIDs: [String]? = nil,
        steps: [SmartActionStep]? = nil,
        triggers: [SmartActionTrigger]? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.actionID = actionID
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.stepCount = stepCount
        self.steps = steps ?? stepActionIDs?.map(SmartActionStep.action)
        self.triggers = triggers
        self.isEnabled = isEnabled
    }

    var stepActionIDs: [String]? {
        guard let steps else { return nil }
        let actionIDs = steps.compactMap(\.legacyActionID)
        return actionIDs.count == steps.count ? actionIDs : nil
    }

    static let samples: [SmartAction] = [
        .init(id: "focus", actionID: "smart-focus", title: "办公模式", subtitle: "专注办公", symbol: "moon.stars.fill", tint: .indigo, stepCount: 3),
        .init(id: "meeting", actionID: "smart-meeting", title: "会议模式", subtitle: "做好通话准备", symbol: "video.fill", tint: .blue, stepCount: 3),
        .init(id: "note", actionID: "smart-note", title: "休憩时刻", subtitle: "看看朋友们都在做什么", symbol: "square.and.pencil", tint: .orange, stepCount: 2),
        .init(id: "netflix", actionID: "smart-netflix", title: "Netflix 时间", subtitle: "再看一期我最喜欢的节目", symbol: "play.fill", tint: .red, stepCount: 1),
        .init(id: "google-work", actionID: "smart-google-work", title: "办公模式 Google 套件", subtitle: "立即打开您的 Google 办公应用程序", symbol: "globe", tint: .blue, stepCount: 3),
        .init(id: "microsoft-work", actionID: "smart-microsoft-work", title: "办公模式 MS 套件", subtitle: "立即打开您的 Microsoft 办公应用程序", symbol: "macwindow", tint: .indigo, stepCount: 3),
        .init(id: "web-search", actionID: "smart-web-search", title: "选择并搜索网络", subtitle: "突出显示要在网络上搜索的文本", symbol: "magnifyingglass", tint: .blue, stepCount: 1),
        .init(id: "break", actionID: "smart-break", title: "休息一下", subtitle: "打开音乐和 YouTube，放松一下", symbol: "music.note", tint: .orange, stepCount: 2),
        .init(id: "flights", actionID: "smart-flights", title: "想去哪里？", subtitle: "探索下一次旅行的航班", symbol: "globe", tint: .blue, stepCount: 1),
        .init(id: "shopping", actionID: "smart-shopping", title: "购物优惠", subtitle: "在线查找购物优惠", symbol: "globe", tint: .green, stepCount: 1),
        .init(id: "perplexity", actionID: "smart-perplexity", title: "问问 Perplexity", subtitle: "打开 Perplexity 开始搜索", symbol: "sparkles", tint: .indigo, stepCount: 1),
        .init(id: "firefly", actionID: "smart-firefly", title: "Adobe Firefly", subtitle: "打开 Adobe Firefly 开始创作", symbol: "sparkles", tint: .orange, stepCount: 1),
        .init(id: "copilot", actionID: "smart-copilot", title: "在浏览器上打开 Copilot", subtitle: "打开 Copilot 开始工作", symbol: "macwindow", tint: .blue, stepCount: 1),
        .init(id: "gemini", actionID: "smart-gemini", title: "Google Gemini", subtitle: "打开 Gemini 询问任何问题", symbol: "sparkles", tint: .blue, stepCount: 1),
        .init(id: "ai-reply", actionID: "smart-ai-reply", title: "AI 回复消息", subtitle: "选中文本后准备回复提示词", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "ai-grammar", actionID: "smart-ai-grammar", title: "AI 纠正语法", subtitle: "选中文本后准备语法修改提示词", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "ai-summary", actionID: "smart-ai-summary", title: "AI 汇总文本", subtitle: "选中文本后准备要点摘要提示词", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "ai-translate", actionID: "smart-ai-translate", title: "AI 英语翻译", subtitle: "选中文本后准备英语翻译提示词", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "ai-code", actionID: "smart-ai-code", title: "AI 代码解释", subtitle: "选中代码后准备解释提示词", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "morning", actionID: "smart-morning", title: "清晨设置", subtitle: "打开我常用的应用程序", symbol: "calendar", tint: .yellow, stepCount: 3),
        .init(id: "sports", actionID: "smart-sports", title: "查看最新比分", subtitle: "了解您支持的球队最新表现", symbol: "globe", tint: .green, stepCount: 1),
        .init(id: "browser", actionID: "smart-browser", title: "打开浏览器", subtitle: "立即打开默认浏览器", symbol: "safari.fill", tint: .blue, stepCount: 1),
        .init(id: "screenshot", actionID: "smart-screenshot", title: "快速截屏", subtitle: "截取当前屏幕并保存", symbol: "viewfinder", tint: .purple, stepCount: 1),
        .init(id: "notes-app", actionID: "smart-notes-app", title: "打开备忘录", subtitle: "立即打开备忘录应用", symbol: "note.text", tint: .yellow, stepCount: 1),
        .init(id: "ai-work", actionID: "smart-ai-work", title: "AI 工作台", subtitle: "打开 ChatGPT 开始新的工作会话", symbol: "sparkles", tint: .purple, stepCount: 1),
        .init(id: "github", actionID: "smart-github", title: "打开 GitHub", subtitle: "打开 GitHub 工作台", symbol: "globe", tint: .gray, stepCount: 1),
        .init(id: "developer-docs", actionID: "smart-developer-docs", title: "开发者文档", subtitle: "打开 Apple 开发者文档", symbol: "macwindow", tint: .blue, stepCount: 1)
    ]

    var persistedRepresentation: PersistedSmartAction {
        PersistedSmartAction(
            id: id,
            actionID: actionID,
            title: title,
            stepActionIDs: stepActionIDs,
            steps: steps,
            triggers: triggers,
            isEnabled: isEnabled
        )
    }

    var remoteAction: RemoteAction {
        RemoteAction(
            id: actionID,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            category: .shortcut,
            tint: tint
        )
    }

    static func restored(from saved: PersistedSmartAction) -> SmartAction? {
        let template = samples.first(where: { $0.actionID == saved.actionID })
        let persistedSteps = saved.steps ?? saved.stepActionIDs?.map(SmartActionStep.action)
        let effectiveSteps = persistedSteps ?? (template == nil ? [] : [.action(saved.actionID)])
        guard template != nil || !effectiveSteps.isEmpty,
              effectiveSteps.allSatisfy(\.isValidForSmartAction) else {
            return nil
        }

        let usesTemplatePresentation = persistedSteps == nil
            || persistedSteps == [.action(saved.actionID)]
        let firstStep = effectiveSteps.first
        return SmartAction(
            id: saved.id,
            actionID: saved.actionID,
            title: saved.title,
            subtitle: usesTemplatePresentation
                ? (template?.subtitle ?? workflowSubtitle(for: effectiveSteps))
                : workflowSubtitle(for: effectiveSteps),
            symbol: usesTemplatePresentation
                ? (template?.symbol ?? firstStep?.symbol ?? "bolt.horizontal.circle")
                : (firstStep?.symbol ?? "bolt.horizontal.circle"),
            tint: usesTemplatePresentation
                ? (template?.tint ?? firstStep?.tint ?? .purple)
                : (firstStep?.tint ?? .purple),
            stepCount: workflowStepCount(for: effectiveSteps),
            steps: persistedSteps,
            triggers: saved.triggers,
            isEnabled: saved.isEnabled ?? true
        )
    }

    func withEnabled(_ enabled: Bool) -> SmartAction {
        SmartAction(
            id: id,
            actionID: actionID,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            tint: tint,
            stepCount: stepCount,
            steps: steps,
            triggers: triggers,
            isEnabled: enabled
        )
    }

    var isEligibleWorkflow: Bool {
        if let steps {
            return !steps.isEmpty && steps.allSatisfy(\.isValidForSmartAction)
        }
        guard let action = RemoteAction.catalog.first(where: { $0.id == actionID }) else {
            return false
        }
        return action.isEligible(for: .smartActionStep)
            && ActionCommand.command(for: actionID) != .none
    }

    static func workflowStepCount(for actionIDs: [String]) -> Int {
        actionIDs.reduce(into: 0) { count, actionID in
            count += samples.first(where: { $0.actionID == actionID })?.stepCount ?? 1
        }
    }

    static func workflowSubtitle(for actionIDs: [String]) -> String {
        let titles = actionIDs.prefix(2).compactMap { actionID in
            RemoteAction.catalog.first(where: { $0.id == actionID })?.title
        }
        let count = workflowStepCount(for: actionIDs)
        guard !titles.isEmpty else { return "\(count) 个步骤" }
        return "\(count) 个步骤 · \(titles.joined(separator: "、"))"
    }

    static func workflowStepCount(for steps: [SmartActionStep]) -> Int {
        steps.reduce(into: 0) { count, step in
            if case let .action(actionID) = step {
                count += samples.first(where: { $0.actionID == actionID })?.stepCount ?? 1
            } else {
                count += 1
            }
        }
    }

    static func workflowSubtitle(for steps: [SmartActionStep]) -> String {
        let count = workflowStepCount(for: steps)
        let titles = steps.prefix(2).map(\.title)
        guard !titles.isEmpty else { return "\(count) 个步骤" }
        return "\(count) 个步骤 · \(titles.joined(separator: "、"))"
    }
}

extension SmartActionStep {
    var isValidForSmartAction: Bool {
        guard isValid else { return false }
        guard case let .action(actionID) = self,
              let action = RemoteAction.catalog.first(where: { $0.id == actionID }) else {
            return true
        }
        return action.isEligible(for: .smartActionStep)
    }

    var title: String {
        switch self {
        case let .action(actionID):
            RemoteAction.catalog.first(where: { $0.id == actionID })?.title ?? actionID
        case let .application(_, name):
            "打开应用 \(name)"
        case let .applicationPath(_, name):
            "打开应用 \(name)"
        case let .applicationControl(_, name, operation):
            "\(operation.title)应用 \(name)"
        case let .keystroke(_, _, name):
            "快捷键：\(name)"
        case let .text(value):
            value.isEmpty ? "粘贴文本" : value
        case let .url(value):
            value.isEmpty ? "打开网址" : value
        case let .delay(milliseconds):
            Self.delayTitle(milliseconds: milliseconds)
        }
    }

    var subtitle: String {
        switch self {
        case let .action(actionID):
            RemoteAction.catalog.first(where: { $0.id == actionID })?.subtitle ?? "系统动作"
        case .application, .applicationPath:
            "打开并切换到应用"
        case let .applicationControl(_, _, operation):
            switch operation {
            case .open: "打开并切换到应用"
            case .close: "结束正在运行的应用"
            case .bringToFront: "将应用的窗口置于前台"
            }
        case .keystroke:
            "发送一次键盘快捷键"
        case .text:
            "粘贴文本，最多 1000 个字符"
        case .url:
            "使用默认浏览器打开"
        case .delay:
            "等待前一个动作完成"
        }
    }

    var symbol: String {
        switch self {
        case let .action(actionID):
            RemoteAction.catalog.first(where: { $0.id == actionID })?.symbol ?? "bolt"
        case .application, .applicationPath, .applicationControl: "app.dashed"
        case .keystroke: "keyboard"
        case .text: "text-cursor-input"
        case .url: "link"
        case .delay: "clock-3"
        }
    }

    var tint: Color {
        switch self {
        case let .action(actionID):
            RemoteAction.catalog.first(where: { $0.id == actionID })?.tint ?? .purple
        case .application, .applicationPath, .applicationControl: .blue
        case .keystroke: .indigo
        case .text: .orange
        case .url: .cyan
        case .delay: .gray
        }
    }

    private static func delayTitle(milliseconds: Int) -> String {
        if milliseconds % 1000 == 0 {
            return "\(milliseconds / 1000) 秒延迟"
        }
        return String(format: "%.1f 秒延迟", Double(milliseconds) / 1000)
    }
}
