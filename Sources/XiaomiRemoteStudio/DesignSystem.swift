import AppKit
import SwiftUI

// MARK: - Visual tokens

/// The app uses the native SF family. Persistent copy never drops below 12 pt.
enum AppTypography {
    static let display = Font.system(size: 32, weight: .bold)
    static let pageTitle = Font.system(size: 27, weight: .semibold)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let title = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let label = Font.system(size: 12, weight: .semibold)
    static let supporting = Font.system(size: 12)
    static let supportingMedium = Font.system(size: 12, weight: .medium)
    static let numeric = Font.system(size: 12, weight: .semibold, design: .monospaced)
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
    static let purple = Color(red: 0.48, green: 0.30, blue: 0.95)
    static let purplePressed = Color(red: 0.39, green: 0.22, blue: 0.84)
    static let mint = Color(red: 0.00, green: 0.82, blue: 0.70)
    static let success = Color(red: 0.10, green: 0.68, blue: 0.43)
    static let warning = Color(red: 0.92, green: 0.55, blue: 0.16)

    static func canvas(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.075, green: 0.078, blue: 0.088)
            : Color(red: 0.965, green: 0.967, blue: 0.975)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.115, green: 0.118, blue: 0.132)
            : Color(red: 0.995, green: 0.995, blue: 0.998)
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.145, green: 0.148, blue: 0.164)
            : Color(red: 0.935, green: 0.938, blue: 0.950)
    }

    static func separator(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.085)
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
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppTheme.onAccent(for: colorScheme))
            .padding(.horizontal, 18)
            .frame(height: AppMetrics.controlHeight)
            .background(AppTheme.accent(for: colorScheme).opacity(configuration.isPressed ? 0.80 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? 0.62 : 1))
            .padding(.horizontal, 16)
            .frame(height: AppMetrics.controlHeight)
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
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

struct RemoteProductImage: View {
    private static let image: NSImage? = {
        guard let url = Bundle.module.url(forResource: "remote-product-v5-premium", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        Group {
            if let image = Self.image {
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
