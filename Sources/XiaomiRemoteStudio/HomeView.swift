import SwiftUI

enum HomeDeviceCardMetrics {
    // Options+ keeps the connected artwork at full opacity and applies an
    // exact 40% alpha only while the device is unavailable.
    static let connectedProductOpacity: CGFloat = 1
    static let unavailableProductOpacity: CGFloat = 0.4
    static let productFrameHeight: CGFloat = 228
    // The hardware render stays optically anchored on hover. Movement here
    // makes a physical device feel weightless and was explicitly rejected in
    // the interaction review.
    static let productOffsetY: CGFloat = 19
    static let idleShadowOpacity: CGFloat = 0.05
}

enum HomeUnavailableDevicePresentation {
    static func actionTitle(
        connectionState: DeviceConnectionState,
        inputServiceEnabled: Bool
    ) -> String {
        guard inputServiceEnabled else { return "启用" }
        return connectionState == .connecting ? "正在连接" : "蓝牙设置"
    }
}

enum HomeGreeting {
    static func title(forHour hour: Int) -> String {
        if hour < 12 { return "早上好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            // MiCoding manages one supported device. The empty state already
            // owns the single add-device CTA, so the toolbar stays focused on
            // Smart Actions and Settings instead of repeating that action.
            RootToolbar(title: greeting)

            GeometryReader { proxy in
                if store.remoteIsManaged {
                    HomeDeviceCard()
                        .position(
                            x: proxy.size.width / 2,
                            y: proxy.size.height / 2 - 35
                        )

                    if store.showExperienceRecommendations {
                        HomeExperienceHint {
                            store.setExperienceRecommendations(false)
                        }
                        .position(
                            x: proxy.size.width / 2,
                            y: proxy.size.height / 2 + 190
                        )
                        .transition(.opacity)
                    }

                    if store.showPermissionReminders
                        && (!store.permissions.inputMonitoringGranted
                            || !store.permissions.accessibilityGranted) {
                        PermissionRecoveryBanner()
                            .frame(width: 520)
                            .position(x: proxy.size.width / 2, y: proxy.size.height - 46)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    HomeEmptyDeviceState()
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2 - 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: store.showExperienceRecommendations)
            .animation(.easeOut(duration: 0.18), value: store.permissions)
            .animation(.easeOut(duration: 0.18), value: store.remoteIsManaged)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return HomeGreeting.title(forHour: hour)
    }
}

private struct HomeEmptyDeviceState: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            RemoteProductImage()
                .frame(width: 74, height: 188)
                .opacity(0.28)
                .grayscale(1)

            Text("尚未添加设备")
                .font(.custom("AvenirNext-Bold", size: 25))
                .padding(.top, 25)

            Text("添加 Xiaomi Remote 2 Pro 后即可配置按键、应用 Profile 和 Smart Actions。")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 430)
                .padding(.top, 9)

            Button {
                store.beginAddingDevice()
            } label: {
                HStack(spacing: 8) {
                    AppIcon(symbol: "plus", size: AppIconSize.control)
                    Text("添加设备")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 24)
        }
        .frame(width: 520, height: 410)
        .accessibilityElement(children: .contain)
    }
}

private struct HomeExperienceHint: View {
    let dismiss: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 13) {
            AppIcon(symbol: "circle-dot", size: 18)
                .foregroundStyle(AppTheme.accent(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(AppTheme.accent(for: colorScheme).opacity(0.09))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("进阶控制")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppTheme.text(for: colorScheme))
                Text("了解长按、双击与 Actions Ring")
                    .font(AppTypography.supporting)
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 12)

            Button("查看用法") {
                store.showExploreCenter()
            }
            .font(AppTypography.supportingMedium)
            .buttonStyle(QuietButtonStyle())
            .foregroundStyle(AppTheme.accent(for: colorScheme))
            .frame(height: 36)
            .help("打开探索中心")

            Button(action: dismiss) {
                AppIcon(symbol: "xmark", size: 11)
                    .foregroundStyle(Color.secondary.opacity(0.68))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("关闭推荐")
            .accessibilityLabel("关闭推荐")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(width: 430, height: 58)
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct HomeDeviceCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsResetConfirmation = false
    @State private var showsRemovalConfirmation = false

    var body: some View {
        VStack(spacing: 44) {
            Button {
                store.openDevice(.remote2Pro)
            } label: {
                RemoteProductImage(artwork: .perspective)
                    .frame(width: 96, height: HomeDeviceCardMetrics.productFrameHeight)
                    // Keep the device quieter than the detail-page hero while
                    // preserving the side face and material contrast that give
                    // the reference product card its visual weight.
                    .opacity(productOpacity)
                    .shadow(
                        color: .black.opacity(HomeDeviceCardMetrics.idleShadowOpacity),
                        radius: 16,
                        y: 10
                    )
                    .offset(y: HomeDeviceCardMetrics.productOffsetY)
                    // Options+ keeps the entire 393 × 363 device column
                    // clickable, including the otherwise-empty area around
                    // and below the product render. Keep the image anchored
                    // at the same top edge while matching that larger target.
                    .frame(width: 393, height: 363, alignment: .top)
                    .contentShape(Rectangle())
            }
            // The reference hit target overlaps the separate connection tile;
            // remove the extra layout height so neither visible element moves.
            .padding(.bottom, -123)
            .buttonStyle(QuietButtonStyle())
            .help("打开按键配置")
            .accessibilityLabel(RemoteDevice.remote2Pro.name)
            .accessibilityValue(deviceAccessibilityValue)
            .accessibilityHint("打开按键配置")

            if deviceIsAvailable {
                HomeConnectedControls()
            } else {
                HomeDisconnectedControls(
                    title: unavailableStateTitle,
                    recover: recoverUnavailableDevice
                ) {
                    showsRemovalConfirmation = true
                }
            }
        }
        .contextMenu {
            Button(store.inputServiceEnabled ? "停用设备" : "启用设备") {
                store.setInputServiceEnabled(!store.inputServiceEnabled)
            }
            Divider()
            Button("从 MiCoding 移除设备", role: .destructive) {
                showsRemovalConfirmation = true
            }
            Button("清除所有按键配置", role: .destructive) {
                showsResetConfirmation = true
            }
        }
        .confirmationDialog(
            "清除遥控器配置？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除所有按键配置", role: .destructive) {
                store.resetDeviceConfiguration()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会清除所有应用 Profile 中的单击、长按和双击分配。")
        }
        .confirmationDialog(
            "从 MiCoding 移除设备？",
            isPresented: $showsRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("移除并打开蓝牙设置", role: .destructive) {
                store.removeManagedDevice()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("MiCoding 会停止管理并从首页移除此设备，但保留按键配置。若要取消系统配对，请在随后打开的 macOS 蓝牙设置中选择“忽略此设备”。")
        }
    }

    private var productOpacity: CGFloat {
        guard deviceIsAvailable else {
            return HomeDeviceCardMetrics.unavailableProductOpacity
        }
        return HomeDeviceCardMetrics.connectedProductOpacity
    }

    private var deviceIsAvailable: Bool {
        store.connectionState == .connected && store.inputServiceEnabled
    }

    private var unavailableStateTitle: String {
        HomeUnavailableDevicePresentation.actionTitle(
            connectionState: store.connectionState,
            inputServiceEnabled: store.inputServiceEnabled
        )
    }

    private func recoverUnavailableDevice() {
        if !store.inputServiceEnabled {
            store.setInputServiceEnabled(true)
        } else {
            store.openBluetoothSettings()
        }
    }

    private var deviceAccessibilityValue: String {
        guard store.connectionState == .connected else {
            return store.connectionState.title
        }
        let battery = store.batteryLevel.map { "，电量 \($0)%" } ?? "，电量设备未上报"
        return "\(store.connectionState.title)\(battery)"
    }
}

private struct HomeConnectedControls: View {
    var body: some View {
        HomeConnectionTile()
    }
}

private struct HomeConnectionTile: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsDeviceStatus = false

    var body: some View {
        Button {
            showsDeviceStatus = true
            store.checkDeviceInformation()
        } label: {
            BatteryConnectionStatus(level: store.batteryLevel)
            .contentShape(Rectangle())
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: BatteryConnectionStatusMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BatteryConnectionStatusMetrics.cornerRadius, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(QuietButtonStyle())
        .help(connectionHelp)
        .accessibilityLabel("遥控器连接状态")
        .accessibilityValue(connectionHelp)
        .contextMenu {
            Button("刷新电量") { store.checkDeviceInformation() }
            Button("打开蓝牙设置") { store.openBluetoothSettings() }
        }
        .popover(isPresented: $showsDeviceStatus, arrowEdge: .bottom) {
            DeviceConnectionStatusPopover(
                deviceName: RemoteDevice.remote2Pro.name,
                level: store.batteryLevel,
                firmwareVersion: store.firmwareVersion,
                connected: store.connectionState == .connected,
                refresh: store.checkDeviceInformation,
                openBluetoothSettings: store.openBluetoothSettings
            )
        }
    }

    private var connectionHelp: String {
        let battery = store.batteryLevel.map { "电量 \($0)%" } ?? "电量设备未上报"
        return "已连接 · \(battery) · 点击刷新"
    }
}

private struct HomeDisconnectedControls: View {
    let title: String
    let recover: () -> Void
    let removeDevice: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Button(action: recover) {
                Text(title)
                    .font(AppTypography.supporting)
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .padding(.horizontal, 14)
                    .frame(minWidth: 54)
                    .frame(height: 40)
                    .contentShape(Rectangle())
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    }
            }
            .buttonStyle(QuietButtonStyle())
            .help(store.inputServiceEnabled ? "打开蓝牙设置" : "重新启用设备")

            HomeRemoveDeviceButton(action: removeDevice)
        }
    }
}

private struct HomeRemoveDeviceButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            AppIcon(symbol: "trash", size: AppIconSize.control)
                .foregroundStyle(Color.primary.opacity(0.82))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .background(AppTheme.surface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                }
        }
        .buttonStyle(QuietButtonStyle())
        .help("从 MiCoding 移除设备")
        .accessibilityLabel("从 MiCoding 移除设备")
    }
}
