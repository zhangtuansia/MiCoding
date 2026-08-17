import SwiftUI

/// A focused pairing surface for the only device MiCoding currently supports.
/// macOS owns Bluetooth pairing; this screen explains that hand-off, keeps
/// checking for the remote, and asks for confirmation before MiCoding adopts it.
struct ConnectionTypePickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    private var pairingState: PairingState {
        guard store.devicePresent else { return .searching }
        return store.remoteIsManaged ? .alreadyManaged : .readyToAdd
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(AppTheme.separator(for: colorScheme))

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 84) {
                        productPresentation
                        pairingDetails
                    }
                    .frame(maxWidth: 984)
                    .frame(
                        minHeight: max(560, proxy.size.height - 2),
                        alignment: .center
                    )
                    .padding(.horizontal, 48)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(AppTheme.canvas(for: colorScheme).ignoresSafeArea())
        .task {
            // Keep the existing two-second discovery cadence, but only refresh
            // device information here. Adoption remains an explicit user act.
            while !Task.isCancelled, store.showsConnectionTypePicker {
                store.refreshDeviceInformation()
                guard store.showsConnectionTypePicker else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("添加 Xiaomi Bluetooth Remote 2 Pro")
    }

    private var header: some View {
        ZStack {
            Text("添加遥控器")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppTheme.text(for: colorScheme))

            HStack {
                Button {
                    store.cancelAddingDevice()
                } label: {
                    AppIcon(symbol: "chevron.left", size: AppIconSize.navigation)
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)
                .help("返回")
                .accessibilityLabel("返回设备列表")

                Spacer()

                PairingStatusLabel(state: pairingState)
            }
            .padding(.horizontal, 34)
        }
        .frame(height: AppMetrics.headerHeight)
    }

    private var productPresentation: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppTheme.primarySurface(for: colorScheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    }

                RemoteProductImage(artwork: .perspective)
                    .frame(width: 126, height: 442)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.13),
                        radius: 18,
                        y: 14
                    )
                    .padding(.bottom, 20)
            }
            .frame(width: 318, height: 488)

            VStack(spacing: 4) {
                Text("Xiaomi Bluetooth Remote 2 Pro")
                    .font(AppTypography.title)
                    .foregroundStyle(AppTheme.text(for: colorScheme))

                Text("蓝牙遥控器")
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(width: 318)
    }

    private var pairingDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("XIAOMI BLUETOOTH")
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .tracking(1.1)
                .foregroundStyle(Color.secondary)

            Text(pairingState.title)
                .font(AppTypography.settingsTitle)
                .tracking(-0.35)
                .foregroundStyle(AppTheme.text(for: colorScheme))
                .padding(.top, 8)

            Text(pairingState.description)
                .font(AppTypography.body)
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            discoveryStatus
                .padding(.top, 24)

            Text("配对方法")
                .font(.custom("AvenirNext-DemiBold", size: 14))
                .foregroundStyle(AppTheme.text(for: colorScheme))
                .padding(.top, 27)

            VStack(alignment: .leading, spacing: 17) {
                PairingStep(
                    number: 1,
                    title: "让遥控器进入配对模式",
                    detail: "按设备说明操作，直到遥控器的指示灯开始闪烁。"
                )
                PairingStep(
                    number: 2,
                    title: "在 macOS 蓝牙中完成连接",
                    detail: "在附近设备中选择 Xiaomi Bluetooth Remote 2 Pro。"
                )
                PairingStep(
                    number: 3,
                    title: "返回 MiCoding 确认采用",
                    detail: "检测到设备后，点击“使用此遥控器”完成添加。"
                )
            }
            .padding(.top, 16)

            actionButtons
                .padding(.top, 30)

            Text("没有发现设备？请确认遥控器有电，且未连接到其他主机。")
                .font(.custom("AvenirNext-Regular", size: 13))
                .foregroundStyle(Color.secondary)
                .padding(.top, 15)
        }
        .frame(width: 470, alignment: .leading)
    }

    private var discoveryStatus: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(pairingState.tint(for: colorScheme).opacity(0.10))

                AppIcon(symbol: pairingState.symbol, size: 19)
                    .foregroundStyle(pairingState.tint(for: colorScheme))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(pairingState.statusTitle)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppTheme.text(for: colorScheme))

                Text(pairingState.statusDetail)
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 12)

            Circle()
                .fill(pairingState.tint(for: colorScheme))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 15)
        .frame(height: 66)
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppMetrics.radiusControl, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(pairingState.primaryActionTitle) {
                switch pairingState {
                case .searching:
                    store.connectWithBluetooth()
                case .readyToAdd:
                    store.finishAddingDevice()
                case .alreadyManaged:
                    store.cancelAddingDevice()
                }
            }
            .buttonStyle(PrimaryActionButtonStyle(width: 174))
            .accessibilityHint(pairingState.primaryActionHint)

            Button("重新检查") {
                store.refreshDeviceInformation()
            }
            .buttonStyle(SecondaryActionButtonStyle(width: 116))
            .help("重新检查遥控器连接状态")

            if pairingState != .searching {
                Button("蓝牙设置") {
                    store.openBluetoothSettings()
                }
                .buttonStyle(SecondaryActionButtonStyle(width: 116))
                .help("打开 macOS 蓝牙设置")
            }
        }
    }
}

private enum PairingState: Equatable {
    case searching
    case readyToAdd
    case alreadyManaged

    var title: String {
        switch self {
        case .searching: "连接 Remote 2 Pro"
        case .readyToAdd: "遥控器已就绪"
        case .alreadyManaged: "遥控器已经添加"
        }
    }

    var description: String {
        switch self {
        case .searching:
            "在 macOS 中完成蓝牙配对。MiCoding 会在本机检查设备，不需要账号或云端服务。"
        case .readyToAdd:
            "已通过蓝牙发现这台遥控器。确认后，MiCoding 才会开始管理它的按键。"
        case .alreadyManaged:
            "这台遥控器已经由 MiCoding 管理，无需再次添加。"
        }
    }

    var statusTitle: String {
        switch self {
        case .searching: "正在等待遥控器"
        case .readyToAdd: "已发现 Xiaomi Remote 2 Pro"
        case .alreadyManaged: "设备已在 MiCoding 中"
        }
    }

    var statusDetail: String {
        switch self {
        case .searching: "每 2 秒检查一次蓝牙连接状态"
        case .readyToAdd: "蓝牙已连接，等待您的确认"
        case .alreadyManaged: "按键配置与输入服务保持不变"
        }
    }

    var symbol: String {
        switch self {
        case .searching: "scan"
        case .readyToAdd, .alreadyManaged: "checkmark.circle"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .searching: "打开蓝牙设置"
        case .readyToAdd: "使用此遥控器"
        case .alreadyManaged: "返回设备"
        }
    }

    var primaryActionHint: String {
        switch self {
        case .searching: "前往 macOS 蓝牙设置完成配对"
        case .readyToAdd: "将发现的遥控器添加到 MiCoding"
        case .alreadyManaged: "返回设备列表"
        }
    }

    func tint(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .searching: AppTheme.accent(for: colorScheme)
        case .readyToAdd, .alreadyManaged: AppTheme.success
        }
    }
}

private struct PairingStatusLabel: View {
    let state: PairingState

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(state.tint(for: colorScheme))
                .frame(width: 7, height: 7)

            Text(state == .searching ? "等待连接" : "已发现")
                .font(.custom("AvenirNext-Medium", size: 13))
        }
        .foregroundStyle(Color.secondary)
        .padding(.horizontal, 12)
        .frame(height: AppMetrics.statusPillHeight)
        .background(AppTheme.primarySurface(for: colorScheme))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PairingStep: View {
    let number: Int
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", number))
                .font(.custom("AvenirNext-DemiBold", size: 12).monospacedDigit())
                .foregroundStyle(AppTheme.accent(for: colorScheme))
                .frame(width: 28, height: 28)
                .background(AppTheme.accent(for: colorScheme).opacity(0.09))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppTheme.text(for: colorScheme))

                Text(detail)
                    .font(.custom("AvenirNext-Regular", size: 13))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
