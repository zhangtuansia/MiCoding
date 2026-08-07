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
    let batteryLevel: Int?
    let slotCount: Int

    static let remote2Pro = RemoteDevice(
        id: "xiaomi-remote-2-pro",
        name: "Xiaomi Bluetooth Remote 2 Pro",
        model: "蓝牙遥控器",
        batteryLevel: nil,
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

    func accepts(_ action: RemoteAction) -> Bool {
        allowedCategories.isEmpty
            || action.category == .recommended
            || allowedCategories.contains(action.category)
    }

    static let demoSlots: [RemoteButtonSlot] = [
        .init(id: "power", name: "电源", symbol: "power", x: 0.295, y: 0.110, width: 0.19, height: 0.055, shape: .circle, allowedCategories: [.system, .apps, .shortcut]),
        .init(id: "assistant", name: "语音", symbol: "mic.fill", x: 0.705, y: 0.110, width: 0.19, height: 0.055, shape: .circle, allowedCategories: [.system, .apps, .shortcut]),
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

struct RemoteAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let category: ActionCategory
    let tint: Color

    static let catalog: [RemoteAction] = [
        .init(id: "mission-control", title: "调度中心", subtitle: "查看所有窗口", symbol: "rectangle.3.group", category: .recommended, tint: .purple),
        .init(id: "spotlight", title: "聚焦搜索", subtitle: "快速查找内容", symbol: "magnifyingglass", category: .recommended, tint: .indigo),
        .init(id: "play-pause", title: "播放 / 暂停", subtitle: "控制当前媒体", symbol: "playpause.fill", category: .media, tint: .pink),
        .init(id: "next-track", title: "下一首", subtitle: "跳到下一媒体", symbol: "forward.end.fill", category: .media, tint: .orange),
        .init(id: "volume-up", title: "音量增加", subtitle: "系统音量 +5%", symbol: "speaker.plus.fill", category: .media, tint: .blue),
        .init(id: "volume-down", title: "音量减少", subtitle: "系统音量 -5%", symbol: "speaker.minus.fill", category: .media, tint: .blue),
        .init(id: "mute", title: "静音", subtitle: "切换系统静音", symbol: "speaker.slash.fill", category: .media, tint: .red),
        .init(id: "desktop", title: "显示桌面", subtitle: "隐藏全部窗口", symbol: "macwindow", category: .system, tint: .teal),
        .init(id: "lock", title: "锁定屏幕", subtitle: "立即锁定 Mac", symbol: "lock.fill", category: .system, tint: .gray),
        .init(id: "screenshot", title: "区域截图", subtitle: "选择区域并截图", symbol: "viewfinder", category: .system, tint: .green),
        .init(id: "launch-browser", title: "打开浏览器", subtitle: "启动默认浏览器", symbol: "safari.fill", category: .apps, tint: .blue),
        .init(id: "launch-music", title: "打开音乐", subtitle: "启动音乐应用", symbol: "music.note", category: .apps, tint: .pink),
        .init(id: "smart-focus", title: "进入专注模式", subtitle: "音乐、播放与桌面整理", symbol: "moon.stars.fill", category: .shortcut, tint: .indigo),
        .init(id: "smart-meeting", title: "会议准备", subtitle: "日历、FaceTime 与静音", symbol: "video.fill", category: .shortcut, tint: .blue),
        .init(id: "smart-note", title: "快速记录", subtitle: "打开备忘录并新建笔记", symbol: "square.and.pencil", category: .shortcut, tint: .orange)
    ]
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
        .init(id: "safari", title: "Safari", subtitle: "浏览网页", symbol: "safari.fill", tint: .blue, bundleIdentifier: "com.apple.Safari"),
        .init(id: "music", title: "音乐", subtitle: "媒体控制", symbol: "music.note", tint: .pink, bundleIdentifier: "com.apple.Music"),
        .init(id: "final-cut", title: "Final Cut Pro", subtitle: "剪辑工作区", symbol: "scissors", tint: .indigo, bundleIdentifier: "com.apple.FinalCut")
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

    static let samples: [SmartAction] = [
        .init(id: "focus", actionID: "smart-focus", title: "进入专注模式", subtitle: "打开音乐 · 开始播放 · 显示桌面", symbol: "moon.stars.fill", tint: .indigo, stepCount: 3),
        .init(id: "meeting", actionID: "smart-meeting", title: "会议准备", subtitle: "打开日历 · 打开 FaceTime · 静音媒体", symbol: "video.fill", tint: .blue, stepCount: 3),
        .init(id: "note", actionID: "smart-note", title: "快速记录", subtitle: "打开备忘录 · 新建一条笔记", symbol: "square.and.pencil", tint: .orange, stepCount: 2)
    ]
}
