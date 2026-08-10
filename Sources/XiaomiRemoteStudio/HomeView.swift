import SwiftUI

enum HomeDeviceCardMetrics {
    // Options+ keeps the connected artwork at full opacity and applies an
    // exact 40% alpha only while the device is unavailable.
    static let connectedProductOpacity: CGFloat = 1
    static let unavailableProductOpacity: CGFloat = 0.4
    static let productFrameHeight: CGFloat = 228
    // Its hover treatment is a pure 12 pt lift: no scale or alpha change.
    static let idleProductOffsetY: CGFloat = 19
    static let hoveredProductOffsetY: CGFloat = 7
    static let idleShadowOpacity: CGFloat = 0.05
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
            RootToolbar(title: greeting, showAddDevice: true)

            GeometryReader { proxy in
                if store.remoteIsManaged {
                    HomeDeviceCard()
                        .position(
                            x: proxy.size.width / 2 - (store.showExperienceRecommendations ? 196.5 : 0),
                            y: proxy.size.height / 2 - 35
                        )

                    if store.showExperienceRecommendations {
                        HomeExperienceCard {
                            store.setExperienceRecommendations(false)
                        }
                        .position(
                            x: proxy.size.width / 2 + 197,
                            y: proxy.size.height / 2 - 35
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    if store.showPermissionReminders
                        && (!store.permissions.inputMonitoringGranted
                            || !store.permissions.accessibilityGranted) {
                        PermissionRecoveryBanner()
                            .frame(width: 560)
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

private struct HomeExperienceCard: View {
    let dismiss: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Text("升级设备体验")
                .font(AppTypography.supportingMedium)
                .scaleEffect(y: 15 / 16, anchor: .top)
                .foregroundStyle(
                    Color.primary.opacity(colorScheme == .dark ? 0.32 : 0.76)
                )
                .offset(y: 4)

            ZStack(alignment: .topLeading) {
                colorScheme == .dark
                    ? Color.black
                    : Color.black.opacity(0.025)

                Text("通过 XIAOMI REMOTE 2 PRO 发掘更多玩法")
                    .font(.custom("AvenirNext-Bold", size: 12))
                    .foregroundStyle(
                        Color.primary.opacity(colorScheme == .dark ? 0.70 : 0.50)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                RemoteProductImage()
                    .frame(width: 52, height: 139)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.09), radius: 12, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 5)
            }
            .frame(width: 300, height: 228)
            .clipped()

            HStack(spacing: 8) {
                Button {
                    store.showExploreCenter()
                } label: {
                    HStack(spacing: 6) {
                        Text("探索")
                            .font(.custom("AvenirNext-Regular", size: 11))

                        AppIcon(symbol: "chevron.right", size: AppIconSize.indicator)
                            .foregroundStyle(AppTheme.accent(for: colorScheme))
                    }
                    .offset(x: 2)
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .frame(width: 94, height: 40)
                    .background(colorScheme == .dark ? Color.black : AppTheme.surface(for: colorScheme))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.18)
                                    : AppTheme.separator(for: colorScheme),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .help("打开探索中心")

                Button(action: dismiss) {
                    AppIcon(symbol: "xmark", size: 10)
                        .foregroundStyle(Color.secondary.opacity(0.56))
                        .frame(width: 20, height: 20)
                        .background(AppTheme.surface(for: colorScheme))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(QuietButtonStyle())
                .help("关闭推荐")
                .accessibilityLabel("关闭推荐")
            }
            .offset(y: 11)
        }
        .frame(width: 300)
    }
}

private struct HomeDeviceCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false
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
                    .offset(
                        y: hovered
                            ? HomeDeviceCardMetrics.hoveredProductOffsetY
                            : HomeDeviceCardMetrics.idleProductOffsetY
                    )
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
            .onHover { hovered = $0 }
            .animation(.easeOut(duration: 0.16), value: hovered)
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
        if store.connectionState == .connecting {
            return store.connectionState.title
        }
        return "停用"
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
                    .font(.custom("AvenirNext-Regular", size: 11))
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .frame(width: 54, height: 40)
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
