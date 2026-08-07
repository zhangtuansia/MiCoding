import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.canvas(for: colorScheme)
                .ignoresSafeArea()

            Group {
                if store.activeDeviceID != nil {
                    DeviceDetailView(device: .remote2Pro)
                } else {
                    sectionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let toastMessage = store.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, 18)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.14), value: store.toastMessage)
        .onExitCommand {
            if store.activeDeviceID != nil {
                store.closeDevice()
            } else {
                store.cancelDragging()
            }
        }
        .onAppear { store.startBackend() }
        .onDisappear { store.stopBackend() }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch store.activeSection {
        case .devices:
            HomeView()
        case .automations:
            SmartActionsView()
        case .settings:
            SettingsView()
        }
    }
}

struct RootToolbar: View {
    let title: String
    var eyebrow: String?
    var showAddDevice = false

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(AppTypography.label)
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(AppTypography.display)
                    .tracking(-0.7)
            }

            Spacer()

            if showAddDevice {
                ToolbarItemButton(symbol: "plus", title: "添加设备") {
                    store.openBluetoothSettings()
                }
            }

            if store.activeSection == .automations {
                ToolbarItemButton(symbol: AppSection.devices.icon, title: "设备") {
                    store.selectSection(.devices)
                }
            } else {
                ToolbarItemButton(symbol: AppSection.automations.icon, title: "智能操作") {
                    store.selectSection(.automations)
                }
            }

            toolbarDivider

            ToolbarItemButton(
                symbol: AppSection.settings.icon,
                title: "",
                isActive: store.activeSection == .settings
            ) {
                store.selectSection(.settings)
            }
            .help("设置")
        }
        .padding(.horizontal, 42)
        .padding(.top, 18)
        .frame(height: AppMetrics.heroHeaderHeight)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(AppTheme.separator(for: colorScheme))
            .frame(width: 1, height: 24)
    }
}
