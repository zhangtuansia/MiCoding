import AppKit
import SwiftUI

// MARK: - Visual tokens

/// Options+ uses Brown Pro for its Latin glyphs. Avenir Next is the closest
/// system-provided family, while Chinese text continues to fall back to PingFang.
enum AppTypography {
    static let display = Font.custom("AvenirNext-Bold", size: 33)
    static let latinDisplayFontName = "AvenirNext-DemiBold"
    static let latinDisplay = Font.custom(latinDisplayFontName, size: 33)
    // Brown Pro's 33 px device title has a shorter optical cap height than
    // Avenir Next. At 31 pt the rendered glyph bounds match the reference.
    static let deviceDisplay = Font.custom("AvenirNext-Bold", size: 31)
    static let settingsTitle = Font.custom("AvenirNext-Bold", size: 27)
    static let pageTitle = Font.custom("AvenirNext-Bold", size: 24)
    static let sectionTitle = Font.custom("AvenirNext-DemiBold", size: 20)
    static let title = Font.custom("AvenirNext-DemiBold", size: 16)
    static let settingsNavigation = Font.custom("AvenirNext-DemiBold", size: 13)
    private static let deviceNavigationLatin = Font.custom("AvenirNext-DemiBold", size: 13)
    private static let deviceNavigationFallback = Font.system(size: 13, weight: .regular)
    static let body = Font.custom("AvenirNext-Regular", size: 14)
    static let bodyMedium = Font.custom("AvenirNext-Medium", size: 14)
    static let bodyBold = Font.custom("AvenirNext-Bold", size: 14)
    // Live Options+ CSS uses a 14 px bold action line over a 12 px regular
    // hardware line inside the fixed 58.4 px callout.
    private static let calloutTitleLatin = Font.custom("AvenirNext-DemiBold", size: 14)
    private static let calloutTitleFallback = Font.system(size: 14, weight: .regular)
    private static let smartActionTitleLatin = Font.custom("AvenirNext-Bold", size: 24)
    private static let smartActionTitleFallback = Font.system(size: 24, weight: .medium)
    private static let smartActionDescriptionLatin = Font.custom("AvenirNext-Regular", size: 14)
    private static let smartActionDescriptionFallback = Font.system(size: 14, weight: .medium)
    // Actions Ring uses two distinct Brown face rules in Options+: navigation
    // labels name the Bold face at CSS weight 400 (regular CJK fallback), while
    // orbit labels request weight 700 from the Regular face. Keep those rules
    // separate so Chinese is not made uniformly heavy.
    private static let actionsRingNavigationLatin = Font.custom("AvenirNext-DemiBold", size: 13)
    private static let actionsRingNavigationFallback = Font.system(size: 13, weight: .regular)
    private static let actionsRingActionLatin = Font.custom("AvenirNext-DemiBold", size: 14)
    private static let actionsRingActionFallback = Font.system(size: 14, weight: .bold)
    static let calloutDetail = Font.custom("AvenirNext-Regular", size: 12)
    static let label = Font.custom("AvenirNext-DemiBold", size: 12)
    static let supporting = Font.custom("AvenirNext-Regular", size: 12)
    static let supportingMedium = Font.custom("AvenirNext-Medium", size: 12)
    static let numeric = Font.custom("AvenirNext-DemiBold", size: 12).monospacedDigit()

    /// Brown Pro's named bold face is declared at CSS weight 400 in Options+.
    /// Its Latin glyphs therefore stay bold while unsupported CJK glyphs fall
    /// back to the regular system face. Preserve that mixed-script behavior
    /// instead of making every Chinese label artificially heavy.
    static func deviceNavigationText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: deviceNavigationLatin,
            fallbackFont: deviceNavigationFallback
        )
    }

    static func calloutTitleText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: calloutTitleLatin,
            fallbackFont: calloutTitleFallback
        )
    }

    static func smartActionTitleText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: smartActionTitleLatin,
            fallbackFont: smartActionTitleFallback
        )
    }

    static func smartActionDescriptionText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: smartActionDescriptionLatin,
            fallbackFont: smartActionDescriptionFallback
        )
    }

    static func actionsRingNavigationText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: actionsRingNavigationLatin,
            fallbackFont: actionsRingNavigationFallback
        )
    }

    static func actionsRingActionText(_ value: String) -> Text {
        mixedScriptText(
            value,
            latinFont: actionsRingActionLatin,
            fallbackFont: actionsRingActionFallback
        )
    }

    private static func mixedScriptText(
        _ value: String,
        latinFont: Font,
        fallbackFont: Font
    ) -> Text {
        var runs: [(text: String, latin: Bool)] = []
        for character in value {
            let isLatinRun = character.unicodeScalars.allSatisfy { $0.value < 128 }
            if let last = runs.indices.last, runs[last].latin == isLatinRun {
                runs[last].text.append(character)
            } else {
                runs.append((String(character), isLatinRun))
            }
        }

        return runs.reduce(Text("")) { partial, run in
            partial + Text(run.text).font(run.latin ? latinFont : fallbackFont)
        }
    }
}

enum AppIconSize {
    static let hero: CGFloat = 20
    static let navigation: CGFloat = 18
    static let row: CGFloat = 16
    static let control: CGFloat = 15
    static let indicator: CGFloat = 11
}

enum AppMetrics {
    static let controlHeight: CGFloat = 40
    static let compactControlHeight: CGFloat = 36
    static let inlineActionHeight: CGFloat = 32
    static let statusPillHeight: CGFloat = 30
    static let toastHeight: CGFloat = 42
    static let rowHeight: CGFloat = 64
    static let spaciousRowHeight: CGFloat = 76
    static let headerHeight: CGFloat = 84
    static let heroHeaderHeight: CGFloat = 98
    static let sidebarItemHeight: CGFloat = 72
    static let settingsSidebarItemHeight: CGFloat = 56

    static let radiusSmall: CGFloat = 8
    static let radiusControl: CGFloat = 11
    static let radiusPanel: CGFloat = 18
}

enum AppTheme {
    static let purple = Color(red: 129 / 255, green: 78 / 255, blue: 250 / 255)
    static let purplePressed = Color(red: 96 / 255, green: 57 / 255, blue: 178 / 255)
    static let mint = Color(red: 1 / 255, green: 233 / 255, blue: 209 / 255)
    static let success = Color(red: 69 / 255, green: 176 / 255, blue: 82 / 255)
    // Options+ battery state tokens (`--battery-full` / `--battery-empty`).
    // They are deliberately brighter than the semantic success colour used
    // for status copy elsewhere in the app.
    static let batteryFull = Color(red: 121 / 255, green: 224 / 255, blue: 83 / 255)
    static let batteryEmpty = Color(red: 244 / 255, green: 61 / 255, blue: 61 / 255)
    static let warning = Color(red: 1, green: 164 / 255, blue: 20 / 255)

    static func canvas(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 25 / 255)
            : Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 25 / 255)
            : .white
    }

    /// The reference's `--primary-background-1` token. In dark mode it is
    /// deliberately black, so controls remain distinct from the #191919
    /// content canvas.
    static func primarySurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }

    /// The reference's control border (`--battery-border-color` /
    /// `--shadow-7`) rather than the subtler separator used between rows.
    static func controlBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 51 / 255)
            : Color(white: 240 / 255)
    }

    static func text(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 251 / 255)
            : Color(red: 34 / 255, green: 36 / 255, blue: 37 / 255)
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.145, green: 0.148, blue: 0.164)
            : Color(red: 236 / 255, green: 236 / 255, blue: 236 / 255)
    }

    static func separator(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.065)
    }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? mint : purple
    }

    static func onAccent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.82) : .white
    }
}

struct SurfacePanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var shadow: Bool

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
            .shadow(
                color: shadow ? Color.black.opacity(colorScheme == .dark ? 0.24 : 0.07) : .clear,
                radius: shadow ? 20 : 0,
                y: shadow ? 9 : 0
            )
    }
}

extension View {
    func surfacePanel(cornerRadius: CGFloat = 18, shadow: Bool = false) -> some View {
        modifier(SurfacePanel(cornerRadius: cornerRadius, shadow: shadow))
    }

    func glassPanel(cornerRadius: CGFloat = 18) -> some View {
        surfacePanel(cornerRadius: cornerRadius, shadow: false)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    var width: CGFloat? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppTheme.onAccent(for: colorScheme).opacity(isEnabled ? 1 : 0.68))
            .padding(.horizontal, 18)
            .frame(width: width, height: AppMetrics.controlHeight)
            .background(
                AppTheme.accent(for: colorScheme)
                    .opacity(isEnabled ? (configuration.isPressed ? 0.80 : 1) : 0.32)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .shadow(
                color: Color(red: 55 / 255, green: 32 / 255, blue: 111 / 255)
                    .opacity(isEnabled ? 0.30 : 0.10),
                radius: 4,
                y: 4
            )
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    var width: CGFloat? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundStyle(
                Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.62 : 1) : 0.36)
            )
            .padding(.horizontal, 16)
            .frame(width: width, height: AppMetrics.controlHeight)
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
    }
}

struct InlineActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppTheme.accent(for: colorScheme).opacity(configuration.isPressed ? 0.62 : 1))
            .padding(.horizontal, 10)
            .frame(height: AppMetrics.inlineActionHeight)
            .background(
                AppTheme.accent(for: colorScheme)
                    .opacity(configuration.isPressed ? 0.10 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
    }
}

struct ToolbarItemButton: View {
    let symbol: String
    let title: String
    var isActive = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIcon(symbol: symbol, size: AppIconSize.navigation)
                if !title.isEmpty {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                }
            }
            .foregroundStyle(isActive ? AppTheme.accent(for: colorScheme) : Color.primary)
            .padding(.horizontal, title.isEmpty ? 10 : 12)
            .frame(height: AppMetrics.controlHeight)
            .background((hovered || isActive) ? AppTheme.elevatedSurface(for: colorScheme).opacity(isActive ? 0.95 : 0.58) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
                    .stroke(isActive ? AppTheme.separator(for: colorScheme) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(QuietButtonStyle())
        .onHover { hovered = $0 }
    }
}

struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 38

    var body: some View {
        AppIcon(symbol: symbol, size: max(AppIconSize.row, size * 0.39))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.105))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct BatteryLevelGlyph: View {
    let level: Int?
    var connected = true
    var scale: CGFloat = 1

    var body: some View {
        VStack(spacing: 1 * scale) {
            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                .fill(tint)
                .frame(width: 4 * scale, height: 2 * scale)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.8 * scale, style: .continuous)
                    .stroke(tint, lineWidth: 1.35 * scale)

                if let level {
                    RoundedRectangle(cornerRadius: 0.9 * scale, style: .continuous)
                        .fill(tint)
                        .frame(
                            width: 8 * scale,
                            height: max(
                                2 * scale,
                                12 * scale * CGFloat(min(max(level, 0), 100)) / 100
                            )
                        )
                        .padding(.bottom, 1 * scale)
                }
            }
            .frame(width: 10 * scale, height: 14 * scale)
        }
        .frame(width: AppIconSize.row * scale, height: AppIconSize.row * scale)
        .accessibilityHidden(true)
    }

    private var tint: Color {
        guard connected else { return .secondary }
        guard let level else { return .secondary }
        if level <= 10 { return AppTheme.batteryEmpty }
        return level <= 20 ? AppTheme.warning : AppTheme.batteryFull
    }
}

struct BatteryStatusLabel: View {
    let level: Int?
    var connected = true

    var body: some View {
        HStack(spacing: 6) {
            BatteryLevelGlyph(level: level, connected: connected)

            Text(level.map { "\($0)%" } ?? "--")
                .font(.custom("AvenirNext-DemiBold", size: 11).monospacedDigit())
                .foregroundStyle(textTint)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("遥控器电量")
        .accessibilityValue(level.map { "\($0)%" } ?? "设备未上报")
    }

    private var textTint: Color {
        guard connected, let level else { return .secondary }
        return level <= 20 ? AppTheme.warning : .primary
    }
}

enum BatteryConnectionStatusMetrics {
    static let compactControlWidth: CGFloat = 54
    static let reportedControlWidth: CGFloat = 103
    static let controlHeight: CGFloat = 40
    static let horizontalPadding: CGFloat = 6
    static let reportedValueSpacing: CGFloat = 6.5
    static let iconSlotWidth: CGFloat = 26
    static let cornerRadius: CGFloat = 4
}

/// Connection status used by the Options+-sized device tile. Options+ keeps a
/// 54 pt compact control while battery data is unavailable, then expands it to
/// roughly 103 pt for a 26 pt battery glyph, a 15 pt percentage and Bluetooth.
struct BatteryConnectionStatus: View {
    let level: Int?
    var connected = true

    var body: some View {
        HStack(spacing: 0) {
            BatteryLevelGlyph(level: level, connected: connected, scale: 1.35)
                .frame(width: BatteryConnectionStatusMetrics.iconSlotWidth)

            if let level {
                Text("\(level)%")
                    .font(.custom("AvenirNext-DemiBold", size: 15).monospacedDigit())
                    .fixedSize()
                    .padding(.leading, BatteryConnectionStatusMetrics.reportedValueSpacing)
            }

            AppIcon(symbol: "wave.3.right", size: 14)
                .foregroundStyle(connected ? Color.primary : Color.secondary)
                .frame(width: BatteryConnectionStatusMetrics.iconSlotWidth)
        }
        .padding(.horizontal, BatteryConnectionStatusMetrics.horizontalPadding)
        .frame(
            width: level == nil
                ? BatteryConnectionStatusMetrics.compactControlWidth
                : BatteryConnectionStatusMetrics.reportedControlWidth,
            height: BatteryConnectionStatusMetrics.controlHeight
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("遥控器连接状态")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard connected else { return "未连接" }
        return level.map { "已连接，电量 \($0)%" } ?? "已连接，电量设备未上报"
    }
}

/// The reference keeps the device tile visually compact, but a compact glyph
/// alone makes a successfully-read battery value easy to miss. This popover is
/// attached to that tile so the exact level and firmware stay one click away
/// without changing the Options+-sized control itself.
struct DeviceConnectionStatusPopover: View {
    let deviceName: String
    let level: Int?
    let firmwareVersion: String?
    let connected: Bool
    let refresh: () -> Void
    let openBluetoothSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                BatteryLevelGlyph(level: level, connected: connected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceName)
                        .font(AppTypography.bodyMedium)
                        .lineLimit(1)
                    Text(connected ? "已连接" : "未连接")
                        .font(AppTypography.supporting)
                        .foregroundStyle(connected ? AppTheme.success : Color.secondary)
                }

                Spacer(minLength: 8)

                AppIcon(symbol: "wave.3.right", size: 15)
                    .foregroundStyle(connected ? Color.primary : Color.secondary)
            }

            Divider()
                .padding(.vertical, 13)

            statusRow(
                title: "电量",
                value: level.map { "\($0)%" } ?? "设备未上报",
                symbol: level.map { $0 <= 20 ? "battery-low" : "battery" } ?? "battery"
            )

            statusRow(
                title: "固件",
                value: firmwareVersion ?? "未知",
                symbol: "settings"
            )
            .padding(.top, 10)

            HStack(spacing: 8) {
                Button("蓝牙设置", action: openBluetoothSettings)
                    .buttonStyle(SecondaryActionButtonStyle(width: 104))

                Button("刷新", action: refresh)
                    .buttonStyle(PrimaryActionButtonStyle(width: 104))
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(width: 252)
        .background(AppTheme.canvas(for: colorScheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("遥控器设备状态")
    }

    private func statusRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            AppIcon(symbol: symbol, size: 15)
                .foregroundStyle(Color.secondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(Color.secondary)

            Spacer()

            Text(value)
                .font(.custom("AvenirNext-DemiBold", size: 12).monospacedDigit())
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
    }
}

struct StatusPill: View {
    let state: DeviceConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(state.color)
                .frame(width: 6, height: 6)
            Text(state.title)
                .font(AppTypography.label)
        }
        .foregroundStyle(state == .disconnected ? Color.secondary : Color.primary)
        .padding(.horizontal, 10)
        .frame(height: AppMetrics.statusPillHeight)
        .background(state.color.opacity(0.085))
        .clipShape(Capsule())
    }
}

struct InlineDeviceStatus: View {
    let state: DeviceConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.color)
                .frame(width: 6, height: 6)
            Text(state.title)
                .font(AppTypography.supportingMedium)
        }
        .foregroundStyle(.secondary)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 9) {
            AppIcon(symbol: "checkmark.circle.fill", size: AppIconSize.row)
                .foregroundStyle(AppTheme.success)
            Text(message)
                .font(AppTypography.bodyMedium)
        }
        .padding(.horizontal, 15)
        .frame(height: AppMetrics.toastHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }
}

struct PermissionRecoveryBanner: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    private var needsInputMonitoring: Bool {
        !store.permissions.inputMonitoringGranted
    }

    private var title: String {
        needsInputMonitoring ? "输入监控未开启" : "辅助功能未开启"
    }

    private var detail: String {
        needsInputMonitoring
            ? "MiCoding 暂时无法接收遥控器按键。"
            : "快捷键、媒体键与窗口操作暂时不可用。"
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(
                symbol: needsInputMonitoring ? "keyboard" : "lock.shield.fill",
                size: AppIconSize.row
            )
            .foregroundStyle(AppTheme.warning)
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.primary)

                Text(detail)
                    .font(AppTypography.supporting)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                if needsInputMonitoring {
                    store.requestInputMonitoringPermission()
                    store.openInputMonitoringSettings()
                } else {
                    store.requestAccessibilityPermission()
                    store.openAccessibilitySettings()
                }
            } label: {
                Text("打开设置")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.primary.opacity(0.90))
                    .padding(.horizontal, 10)
                    .frame(height: AppMetrics.inlineActionHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("打开 macOS 权限设置")

            Button {
                store.setPermissionReminders(false)
            } label: {
                AppIcon(symbol: "xmark", size: AppIconSize.indicator)
                    .foregroundStyle(Color.secondary.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("关闭权限提醒")
            .accessibilityLabel("关闭权限提醒")
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.055),
            radius: 12,
            y: 5
        )
        .accessibilityElement(children: .contain)
    }
}

enum RemoteProductArtwork {
    case front
    case perspective

    fileprivate var resourceName: String {
        switch self {
        case .front: "remote-product-v5-premium"
        case .perspective: "remote-product-v6-perspective"
        }
    }
}

struct RemoteProductImage: View {
    var artwork: RemoteProductArtwork = .front

    private static func loadImage(named resourceName: String) -> NSImage? {
        if let resources = Bundle.main.resourceURL {
            let packagedURL = resources
                .appendingPathComponent("XiaomiRemoteStudio_XiaomiRemoteStudio.bundle", isDirectory: true)
                .appendingPathComponent("\(resourceName).png")
            if let image = NSImage(contentsOf: packagedURL) {
                return image
            }
        }

        guard let developmentURL = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png"
        ) else { return nil }
        return NSImage(contentsOf: developmentURL)
    }

    private static let frontImage = loadImage(named: RemoteProductArtwork.front.resourceName)
    private static let perspectiveImage = loadImage(named: RemoteProductArtwork.perspective.resourceName)

    private var image: NSImage? {
        switch artwork {
        case .front: Self.frontImage
        case .perspective: Self.perspectiveImage
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            }
        }
        .accessibilityHidden(true)
    }
}

struct RemoteMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(AppTheme.purple)
            AppIcon(symbol: "dot.radiowaves.left.and.right", size: AppIconSize.navigation)
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
    }
}
