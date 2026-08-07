import Foundation

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

enum RemoteTrigger: String, Codable, Equatable, Sendable {
    case tap
    case hold
    case doubleTap
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
    case nextTrack
    case volumeUp
    case volumeDown
    case mute
}

indirect enum ActionCommand: Codable, Equatable, Sendable {
    case keyStroke(keyCode: UInt16, flags: UInt64)
    case system(SystemActionName)
    case openApplication(bundleIdentifier: String)
    case openDefaultBrowser
    case delay(milliseconds: Int)
    case sequence([ActionCommand])
    case none

    static func command(for actionID: String) -> ActionCommand {
        switch actionID {
        case "mission-control": .system(.missionControl)
        case "spotlight": .system(.spotlight)
        case "play-pause": .system(.playPause)
        case "next-track": .system(.nextTrack)
        case "volume-up": .system(.volumeUp)
        case "volume-down": .system(.volumeDown)
        case "mute": .system(.mute)
        case "desktop": .system(.showDesktop)
        case "lock": .system(.lockScreen)
        case "screenshot": .system(.screenshotRegion)
        case "launch-browser": .openDefaultBrowser
        case "launch-music": .openApplication(bundleIdentifier: "com.apple.Music")
        case "smart-focus": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Music"),
            .delay(milliseconds: 500),
            .system(.playPause),
            .delay(milliseconds: 120),
            .system(.showDesktop)
        ])
        case "smart-meeting": .sequence([
            .openApplication(bundleIdentifier: "com.apple.iCal"),
            .delay(milliseconds: 450),
            .openApplication(bundleIdentifier: "com.apple.FaceTime"),
            .delay(milliseconds: 450),
            .system(.mute)
        ])
        case "smart-note": .sequence([
            .openApplication(bundleIdentifier: "com.apple.Notes"),
            .delay(milliseconds: 550),
            .keyStroke(keyCode: 45, flags: UInt64(1 << 20))
        ])
        default: .none
        }
    }
}

struct BackendSettings: Codable, Equatable, Sendable {
    var holdMilliseconds = 350
    var doubleTapMilliseconds = 250
    var remoteVendorID = 0x2717
    var remoteProductID = 0x32B8
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
}
