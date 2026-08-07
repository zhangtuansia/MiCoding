import SwiftUI

struct DeviceDetailView: View {
    let device: RemoteDevice

    @Environment(\.colorScheme) private var colorScheme
    @State private var panel: DevicePanel

    init(device: RemoteDevice, initialPanel: DevicePanel = .buttons) {
        self.device = device
        _panel = State(initialValue: initialPanel)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(device: device)

            HStack(spacing: 0) {
                DeviceRail(selection: $panel)

                switch panel {
                case .buttons:
                    RemoteCanvasView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ActionLibraryView()
                        .frame(width: 382)

                case .device:
                    DeviceInformationView(device: device)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
    }
}

enum DevicePanel: String, CaseIterable, Identifiable {
    case buttons
    case device

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buttons: "按键"
        case .device: "设备"
        }
    }

    var symbol: String {
        switch self {
        case .buttons: "button.programmable"
        case .device: "slider.horizontal.3"
        }
    }
}

private struct DeviceRail: View {
    @Binding var selection: DevicePanel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(DevicePanel.allCases) { panel in
                DeviceRailItem(panel: panel, selected: selection == panel) {
                    selection = panel
                }
            }

            Spacer()
        }
        .padding(.top, 14)
        .frame(width: 86)
        .background(AppTheme.surface(for: colorScheme).opacity(0.72))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
        }
    }
}

private struct DeviceRailItem: View {
    let panel: DevicePanel
    let selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                AppIcon(symbol: panel.symbol, size: AppIconSize.navigation)
                Text(panel.title)
                    .font(AppTypography.label)
            }
            .foregroundStyle(selected ? AppTheme.accent(for: colorScheme) : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: AppMetrics.sidebarItemHeight)
            .background(
                selected
                    ? AppTheme.elevatedSurface(for: colorScheme).opacity(0.62)
                    : (hovered ? Color.primary.opacity(0.025) : .clear)
            )
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? AppTheme.accent(for: colorScheme) : .clear)
                    .frame(width: 3, height: 34)
            }
        }
        .buttonStyle(QuietButtonStyle())
        .onHover { hovered = $0 }
    }
}

private struct DetailHeader: View {
    let device: RemoteDevice

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Button {
                store.closeDevice()
            } label: {
                AppIcon(symbol: "chevron.left", size: AppIconSize.control)
                    .frame(width: AppMetrics.controlHeight, height: AppMetrics.controlHeight)
            }
            .buttonStyle(QuietButtonStyle())
            .help("返回设备")

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(AppTypography.title)
                InlineDeviceStatus(state: store.connectionState)
            }

            Spacer()

            ProfilePicker()
        }
        .padding(.horizontal, 20)
        .frame(height: AppMetrics.headerHeight)
        .background(AppTheme.surface(for: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 1)
        }
    }
}

private struct ProfilePicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            ForEach(AppProfile.profiles) { profile in
                Button {
                    store.selectProfile(profile)
                } label: {
                    Label {
                        Text(profile.title)
                    } icon: {
                        AppIcon(symbol: profile.symbol, size: AppIconSize.control)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                AppIcon(symbol: store.activeProfile.symbol, size: AppIconSize.control)
                    .foregroundStyle(.secondary)

                Text(store.activeProfile.title)
                    .font(AppTypography.bodyMedium)

                AppIcon(symbol: "chevron.down", size: AppIconSize.indicator)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: AppMetrics.controlHeight)
            .background(AppTheme.elevatedSurface(for: colorScheme).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

private struct DeviceInformationView: View {
    let device: RemoteDevice

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("设备设置")
                    .font(AppTypography.pageTitle)
                Text("连接状态与本机输入权限")
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 30)

                VStack(spacing: 0) {
                    DeviceInformationRow(title: "连接状态", detail: device.name) {
                        StatusPill(state: store.connectionState)
                    }

                    divider

                    DeviceInformationRow(title: "蓝牙连接", detail: "由 macOS 系统蓝牙管理") {
                        Button("打开蓝牙设置") { store.openBluetoothSettings() }
                            .buttonStyle(InlineActionButtonStyle())
                    }

                    divider

                    DeviceInformationRow(
                        title: "电池电量",
                        detail: device.batteryLevel == nil ? "等待实物校准电量报告" : "设备最近一次上报"
                    ) {
                        Text(device.batteryLevel.map { "\($0)%" } ?? "--")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(.secondary)
                    }

                    divider

                    DeviceInformationRow(title: "输入后端", detail: store.backendLog) {
                        Button("重新检测") {
                            store.restartBackend()
                        }
                        .buttonStyle(InlineActionButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .surfacePanel(cornerRadius: 16, shadow: false)
            }
            .padding(.horizontal, 46)
            .padding(.top, 38)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(height: 1)
    }

}

private struct DeviceInformationRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                Text(detail)
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            trailing
        }
        .frame(height: AppMetrics.rowHeight)
    }
}
