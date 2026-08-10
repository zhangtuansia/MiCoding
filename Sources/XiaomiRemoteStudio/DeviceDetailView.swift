import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum DeviceDetailLayoutMetrics {
    // Retina content captures place the Options+ header arrow/title 14 px
    // left and 12–13 px above the previous SwiftUI rendering. Keep this
    // correction scoped to the header so the already-aligned product canvas
    // and rail geometry remain untouched.
    static let headerLeadingPadding: CGFloat = 41.5
    static let headerClosedYOffset: CGFloat = -37
    static let headerOpenYOffset: CGFloat = -40.5
    static let headerTrailingContentOpenYOffset: CGFloat = 3.5
    static let railLeadingPadding: CGFloat = 47.5
    static let railTopPadding: CGFloat = 152.5
    static let railBottomPadding: CGFloat = 40
    static let connectionTileLeadingPadding: CGFloat = 10.5
    static let connectionTileHorizontalScale: CGFloat = 53 / 54
    static let connectionTileVerticalScale: CGFloat = 39 / 40
    static let railItemTrailingPadding: CGFloat = 12
    static let gestureContentXOffset: CGFloat = 0
    static let gestureContentYOffset: CGFloat = 0
    static let flowContentXOffset: CGFloat = 0
    static let flowContentYOffset: CGFloat = 0
    // Options+ settings content starts at global x=541.625. The persistent
    // device rail consumes 220 pt, leaving this measured inset in the detail
    // content area.
    static let informationLeadingPadding: CGFloat = 321.625
    static let informationContentWidth: CGFloat = 510
    static let informationTextWidth: CGFloat = 500
    static let informationInlineActionXOffset: CGFloat = -6
    static let informationToggleHitWidth: CGFloat = 30
    static let informationToggleHitHeight: CGFloat = 22
    static let informationWarningYOffset: CGFloat = -9.5
    static let informationPostWarningSpacing: CGFloat = 16
    static let informationTopCopyYOffset: CGFloat = -7
    static let informationRefreshButtonYOffset: CGFloat = -5
    static let informationSupportCopyYOffset: CGFloat = 3
    static let informationFeatureTitleYOffset: CGFloat = -2.5
    static let informationFeatureActionsYOffset: CGFloat = 1.5
    static let informationGeneralLabelYOffset: CGFloat = 4
    static let informationGeneralRowYOffset: CGFloat = -4.5
    static let informationOtherLabelYOffset: CGFloat = -10.5
    static let informationBackupTitleYOffset: CGFloat = 4.5
    static let informationBackupDescriptionYOffset: CGFloat = 9.5
    static let informationBackupActionsYOffset: CGFloat = 12
    static let informationViewportExtension: CGFloat = -informationYOffset
    static let informationResetSectionYOffset: CGFloat = 12
    static let informationBodyOpticalScale: CGFloat = 1
    static let informationTitleOpticalScale: CGFloat = 1
    static let informationSupportLinkVerticalScale: CGFloat = 13.5 / 15.5
    static let informationYOffset: CGFloat = -82
    static let railRowHeight: CGFloat = 39
    static let railRowSpacing: CGFloat = 18
    static let railRowPitch: CGFloat = railRowHeight + railRowSpacing
    static let applicationPickerHeaderHeight: CGFloat = 114
    static let applicationPickerHeaderTopPadding: CGFloat = 28
    static let applicationPickerHeaderHorizontalPadding: CGFloat = 32
    static let applicationPickerGlobalTopSpacing: CGFloat = 16
    static let applicationPickerGlobalBottomSpacing: CGFloat = 8
    static let applicationPickerSectionHeight: CGFloat = 48
    static let applicationPickerTitleOpticalOffset: CGFloat = 2
    static let applicationPickerSectionTextOpticalOffset: CGFloat = 8.5
    static let applicationPickerSectionChevronOpticalOffset: CGFloat = -1.5
    static let applicationPickerRowTextOpticalOffset: CGFloat = 2
    static let globalParameterProfileWidth: CGFloat = 236
    static let globalParameterDividerContainerWidth: CGFloat = 48
    static let globalParameterAddApplicationWidth: CGFloat = 140
    static let globalParameterProfileOpticalXOffset: CGFloat = -4
    static let globalParameterAddIconSize: CGFloat = 22.5
    static let globalParameterAddIconOpticalYOffset: CGFloat = -0.75
    static let globalParameterAddContentOpticalXOffset: CGFloat = -0.5
    static let trailingPanelWidth: CGFloat = 1_180 / 3
    // Options+ applies `rgba(0,0,0,.1) 5px 5px 48px` to the fixed trailing
    // configuration panel. SwiftUI's opacity curve is stronger at the edge;
    // 6% with a 24 pt radius reproduces the measured 244...252 gray falloff.
    static let trailingPanelShadowOpacity: CGFloat = 0.06
    static let trailingPanelShadowRadius: CGFloat = 24
    static let trailingPanelShadowX: CGFloat = 5
    static let trailingPanelShadowY: CGFloat = 5
}

struct DeviceDetailView: View {
    private let actionPanelWidth = DeviceDetailLayoutMetrics.trailingPanelWidth

    let device: RemoteDevice

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: AppStore
    @State private var panel: DevicePanel
    @State private var selectedGestureTiming: GestureTimingKind?
    @State private var showsFlowSetup = false

    init(
        device: RemoteDevice,
        initialPanel: DevicePanel = .buttons,
        opensGesturePanel: Bool = false,
        opensFlowSetup: Bool = false
    ) {
        self.device = device
        _panel = State(initialValue: initialPanel)
        _selectedGestureTiming = State(
            initialValue: initialPanel == .gestures && opensGesturePanel ? .hold : nil
        )
        _showsFlowSetup = State(initialValue: initialPanel == .flow && opensFlowSetup)
    }

    private var hasTrailingPanel: Bool {
        store.selectedSlot != nil
            || store.showsApplicationPicker
            || (panel == .gestures && selectedGestureTiming != nil)
    }

    private var headerProfileMode: DetailHeaderProfileMode {
        switch panel {
        case .buttons: .applications
        case .gestures: .globalParameter
        case .flow, .device: .hidden
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                DetailHeader(
                    device: device,
                    trailingInset: hasTrailingPanel ? actionPanelWidth : 0,
                    profileMode: headerProfileMode,
                    closeGesturePanel: selectedGestureTiming == nil
                        ? nil
                        : { selectedGestureTiming = nil }
                )

                HStack(spacing: 0) {
                    if !hasTrailingPanel {
                        DeviceRail(selection: $panel)
                    } else {
                        Color.clear
                            .frame(width: 92)
                    }

                    switch panel {
                    case .buttons:
                        RemoteCanvasView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if hasTrailingPanel {
                            Color.clear
                                .frame(width: actionPanelWidth)
                        }

                    case .gestures:
                        DeviceGestureSettingsView(selection: $selectedGestureTiming)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if selectedGestureTiming != nil {
                            Color.clear
                                .frame(width: actionPanelWidth)
                        }

                    case .flow:
                        DeviceFlowWelcomeView {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showsFlowSetup = true
                            }
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .device:
                        DeviceInformationView(
                            device: device,
                            showFeatureOverview: { store.showFeatureOverview() },
                            showPhysicalKeyTest: { store.showPhysicalKeyTest() }
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            if hasTrailingPanel {
                Button("") {
                    if selectedGestureTiming != nil {
                        selectedGestureTiming = nil
                    } else if store.showsApplicationPicker {
                        store.closeApplicationPicker()
                    } else {
                        store.closeActionLibrary()
                    }
                }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)

                Group {
                    if let selectedGestureTiming {
                        GestureTimingSettingsPanel(kind: selectedGestureTiming)
                    } else if store.showsApplicationPicker {
                        ApplicationProfilePickerView(
                            subtitle: panel == .gestures
                                ? "为常用应用程序自定义指向和滚动设置，提高效率。"
                                : "为常用应用程序自定义按钮，提高效率。"
                        )
                    } else {
                        ActionLibraryView()
                            .id(store.selectedSlotID)
                    }
                }
                .frame(width: actionPanelWidth)
                .frame(maxHeight: .infinity)
                .shadow(
                    color: .black.opacity(
                        colorScheme == .dark
                            ? 0.30
                            : DeviceDetailLayoutMetrics.trailingPanelShadowOpacity
                    ),
                    radius: DeviceDetailLayoutMetrics.trailingPanelShadowRadius,
                    x: DeviceDetailLayoutMetrics.trailingPanelShadowX,
                    y: DeviceDetailLayoutMetrics.trailingPanelShadowY
                )
                .ignoresSafeArea(.container, edges: .top)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(10)

                DetailConnectionTile()
                    // Root content is inset by the transparent titlebar safe
                    // area. These measured coordinates land at the same
                    // bottom-left anchor as Options+ in the 1180 × 760 window.
                    .position(x: 85, y: 668)
                    .zIndex(9)
            }

            if showsFlowSetup {
                DeviceFlowSetupView {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsFlowSetup = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas(for: colorScheme))
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .background(AppTheme.canvas(for: colorScheme))
        .animation(.easeOut(duration: 0.18), value: store.selectedSlotID)
        .animation(.easeOut(duration: 0.18), value: store.showsApplicationPicker)
        .animation(.easeOut(duration: 0.18), value: selectedGestureTiming)
        .animation(.easeOut(duration: 0.18), value: showsFlowSetup)
        .onChange(of: panel) { _, newPanel in
            if newPanel != .gestures {
                selectedGestureTiming = nil
            }
            if newPanel != .flow {
                showsFlowSetup = false
            }
        }
    }
}

enum DevicePanel: String, CaseIterable, Identifiable {
    case buttons
    case gestures
    case flow
    case device

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buttons: "按钮"
        case .gestures: "手势与连按"
        case .flow: "FLOW"
        case .device: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .buttons: "button.programmable"
        case .gestures: "dot.radiowaves.left.and.right"
        case .flow: "macwindow"
        case .device: "line.3.horizontal"
        }
    }
}

private struct DeviceRail: View {
    @Binding var selection: DevicePanel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DeviceDetailLayoutMetrics.railRowSpacing) {
                ForEach(DevicePanel.allCases) { panel in
                    DeviceRailItem(panel: panel, selected: selection == panel) {
                        selection = panel
                    }
                }
            }
            // The Options+ accessibility frames advance exactly 57 pt:
            // y=376, 433, 490, 547 in the 1,180 × 760 reference window.
            .padding(.top, DeviceDetailLayoutMetrics.railTopPadding)

            Spacer()

            DetailConnectionTile()
                .scaleEffect(
                    x: DeviceDetailLayoutMetrics.connectionTileHorizontalScale,
                    y: DeviceDetailLayoutMetrics.connectionTileVerticalScale,
                    anchor: .center
                )
                .padding(.leading, DeviceDetailLayoutMetrics.connectionTileLeadingPadding)
                .padding(.bottom, DeviceDetailLayoutMetrics.railBottomPadding)
        }
        .padding(.leading, DeviceDetailLayoutMetrics.railLeadingPadding)
        .frame(width: 220, alignment: .leading)
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
            HStack(spacing: 16) {
                Group {
                    if panel == .buttons {
                        ProgrammableButtonsIcon()
                    } else if panel == .gestures {
                        GestureTimingIcon()
                    } else if panel == .flow {
                        FlowRailIcon()
                    } else {
                        AppIcon(symbol: panel.symbol, size: AppIconSize.navigation)
                    }
                }
                .frame(width: 24, height: 24)
                AppTypography.deviceNavigationText(panel.title)
            }
            .offset(x: -0.5, y: 2.5)
            .foregroundStyle(selected ? AppTheme.onAccent(for: colorScheme) : Color.primary)
            .padding(.leading, 14)
            .padding(.trailing, DeviceDetailLayoutMetrics.railItemTrailingPadding)
            .frame(height: DeviceDetailLayoutMetrics.railRowHeight)
            .background(
                selected
                    ? AppTheme.accent(for: colorScheme)
                    : (hovered ? Color.primary.opacity(0.025) : .clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        selected
                            ? (colorScheme == .dark
                                ? AppTheme.accent(for: colorScheme).opacity(0.64)
                                : AppTheme.purplePressed)
                            : .clear,
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel(panel.title)
        .accessibilityValue(selected ? "已选择" : "")
        .help(panel.title)
        .onHover { hovered = $0 }
    }
}

private struct GestureTimingIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 1.7)
                .frame(width: 8, height: 8)
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .frame(width: 19, height: 19)
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .frame(width: 19, height: 19)
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct ProgrammableButtonsIcon: View {
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Capsule()
                    .stroke(lineWidth: 2.2)
                    .frame(width: 13, height: 6)
                Circle()
                    .stroke(lineWidth: 2.2)
                    .frame(width: 6, height: 6)
            }
            HStack(spacing: 3) {
                Circle()
                    .stroke(lineWidth: 2.2)
                    .frame(width: 6, height: 6)
                Capsule()
                    .stroke(lineWidth: 2.2)
                    .frame(width: 13, height: 6)
            }
        }
        .scaleEffect(x: 0.83, y: 0.875)
    }
}

private struct FlowRailIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                .stroke(lineWidth: 1.7)
                .frame(width: 17, height: 11)
                .offset(x: -2.5, y: 2)

            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                .stroke(lineWidth: 1.7)
                .frame(width: 17, height: 11)
                .offset(x: 3, y: -2.5)

            Rectangle()
                .fill(.primary)
                .frame(width: 2, height: 4)
                .offset(x: 3, y: 6)

            Capsule()
                .fill(.primary)
                .frame(width: 23, height: 1.7)
                .offset(x: 3, y: 8)
        }
        .frame(width: 24, height: 24)
    }
}

private struct DetailConnectionTile: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsDeviceStatus = false

    var body: some View {
        Button {
            if !store.inputServiceEnabled {
                store.setInputServiceEnabled(true)
            } else if !store.permissions.inputMonitoringGranted {
                store.openInputMonitoringSettings()
            } else if !store.permissions.accessibilityGranted {
                store.openAccessibilitySettings()
            } else {
                showsDeviceStatus = true
                store.checkDeviceInformation()
            }
        } label: {
            BatteryConnectionStatus(
                level: store.batteryLevel,
                connected: store.connectionState == .connected
            )
            .opacity(showsConnectedStatus ? 1 : 0)
            .overlay {
                if !showsConnectedStatus {
                    Text("停用")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(Color.primary.opacity(0.72))
                }
            }
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
        if !store.inputServiceEnabled { return "输入服务已停用 · 点击启用" }
        if !store.permissions.inputMonitoringGranted { return "完成输入监控权限" }
        if !store.permissions.accessibilityGranted { return "完成辅助功能权限" }
        let battery = store.batteryLevel.map { " · 电量 \($0)%" } ?? " · 电量设备未上报"
        return "\(store.connectionState.title)\(battery) · 点击刷新"
    }

    private var showsConnectedStatus: Bool {
        store.connectionState == .connected && store.inputServiceEnabled
    }
}

private enum DetailHeaderProfileMode {
    case hidden
    case applications
    case globalParameter
}

private struct DetailHeader: View {
    let device: RemoteDevice
    let trailingInset: CGFloat
    let profileMode: DetailHeaderProfileMode
    let closeGesturePanel: (() -> Void)?

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if let closeGesturePanel {
                    closeGesturePanel()
                } else if store.selectedSlotID != nil {
                    store.closeActionLibrary()
                } else if store.showsApplicationPicker {
                    store.closeApplicationPicker()
                } else {
                    store.closeDevice()
                }
            } label: {
                // The Options+ icon font's 32 px cell only paints a roughly
                // 15 × 12 pt arrow. Scale the Lucide glyph by its painted
                // bounds rather than copying the font-cell size directly.
                AppIcon(symbol: "arrow.left", size: 24)
                    .scaleEffect(x: 1, y: 0.76)
                    .offset(x: -0.5, y: 1.5)
                    .frame(width: 46, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("返回设备")
            .accessibilityLabel("返回设备列表")

            if trailingInset == 0 {
                Text(device.name)
                    .font(AppTypography.deviceDisplay)
                    .tracking(-0.8)
                    .scaleEffect(y: 41 / 42, anchor: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .offset(x: 1, y: 1.5)
            }

            Spacer()

            switch profileMode {
            case .hidden:
                EmptyView()
            case .applications:
                ProfileStrip(actionPanelOpen: trailingInset > 0)
                    .offset(
                        y: trailingInset > 0
                            ? DeviceDetailLayoutMetrics.headerTrailingContentOpenYOffset
                            : 0
                    )
            case .globalParameter:
                GlobalParameterProfileStrip()
                    .offset(
                        y: trailingInset > 0
                            ? DeviceDetailLayoutMetrics.headerTrailingContentOpenYOffset
                            : 0
                    )
            }
        }
        .padding(.leading, DeviceDetailLayoutMetrics.headerLeadingPadding)
        .padding(.trailing, 40 + trailingInset)
        .padding(.top, 14)
        .frame(height: 112)
        .offset(
            y: trailingInset > 0
                ? DeviceDetailLayoutMetrics.headerOpenYOffset
                : DeviceDetailLayoutMetrics.headerClosedYOffset
        )
    }
}

private struct GlobalParameterProfileStrip: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if let global = store.profiles.first(where: { $0.id == "global" }) {
                    store.selectProfile(global)
                }
            } label: {
                VStack(spacing: 8) {
                    GlobalProfileIcon()
                        .foregroundStyle(AppTheme.accent(for: colorScheme))
                        .frame(width: 30, height: 30)
                        .offset(y: 3)

                    Rectangle()
                        .fill(AppTheme.accent(for: colorScheme))
                        .frame(width: 35, height: 2)
                }
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("全局设置")
            .accessibilityLabel("全局设置")
            .accessibilityAddTraits(.isSelected)

            Rectangle()
                .fill(Color(red: 221 / 255, green: 212 / 255, blue: 212 / 255).opacity(0.49))
                .frame(width: 1, height: 24)
                .frame(width: DeviceDetailLayoutMetrics.globalParameterDividerContainerWidth)

            Button {
                store.showApplicationPicker()
            } label: {
                HStack(spacing: 11) {
                    AppIcon(
                        symbol: "plus",
                        size: DeviceDetailLayoutMetrics.globalParameterAddIconSize
                    )
                        .offset(y: DeviceDetailLayoutMetrics.globalParameterAddIconOpticalYOffset)
                        .frame(width: 20, height: 20)

                    Text("添加应用程序")
                        .font(AppTypography.bodyBold)
                        .lineLimit(1)
                }
                .offset(x: DeviceDetailLayoutMetrics.globalParameterAddContentOpticalXOffset)
                .frame(
                    width: DeviceDetailLayoutMetrics.globalParameterAddApplicationWidth,
                    height: 48
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("添加应用程序")
            .accessibilityLabel("添加应用程序")
        }
        .frame(width: DeviceDetailLayoutMetrics.globalParameterProfileWidth)
        .offset(x: DeviceDetailLayoutMetrics.globalParameterProfileOpticalXOffset, y: 0.5)
    }
}

private struct ProfileStrip: View {
    let actionPanelOpen: Bool

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.profiles) { profile in
                        profileButton(for: profile)
                    }
                }
            }
            .frame(maxWidth: 320)

            Button {
                store.showApplicationPicker()
            } label: {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        AppIcon(symbol: "plus", size: AppIconSize.navigation)
                            .frame(width: 30, height: 30)
                    }
                    .foregroundStyle(
                        store.showsApplicationPicker
                            ? AppTheme.accent(for: colorScheme)
                            : Color.primary
                    )

                    Rectangle()
                        .fill(
                            store.showsApplicationPicker
                                ? AppTheme.accent(for: colorScheme)
                                : Color.clear
                        )
                        .frame(width: 34, height: 2)
                }
                .frame(minWidth: 48)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("选择应用程序")
        }
        .fixedSize()
        .offset(
            x: store.showsApplicationPicker ? -3 : (actionPanelOpen ? -26 : -4),
            y: 0.5
        )
    }

    private func profileButton(for profile: AppProfile) -> some View {
        Button {
            store.selectProfile(profile)
        } label: {
            VStack(spacing: 8) {
                ProfileApplicationIcon(profile: profile)
                    .foregroundStyle(
                        store.selectedProfileID == profile.id && !store.showsApplicationPicker
                            ? AppTheme.accent(for: colorScheme)
                            : Color.primary
                    )

                Rectangle()
                    .fill(
                        store.selectedProfileID == profile.id && !store.showsApplicationPicker
                            ? AppTheme.accent(for: colorScheme)
                            : Color.clear
                    )
                    .frame(width: 34, height: 2)
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .help(profile.title)
        .contextMenu {
            if profile.id != "global" {
                Button("移除 \(profile.title) Profile", role: .destructive) {
                    store.removeApplicationProfile(profile)
                }
            }
        }
    }
}

struct ProfileApplicationIcon: View {
    let profile: AppProfile

    private var applicationImage: NSImage? {
        guard let bundleIdentifier = profile.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        Group {
            if profile.id == "global" {
                GlobalProfileIcon()
                    .offset(y: 3)
            } else if let applicationImage {
                if profile.id == "chrome" || profile.id == "safari" {
                    Image(nsImage: applicationImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .scaleEffect(1.16)
                        .clipShape(Circle())
                } else {
                    Image(nsImage: applicationImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                }
            } else {
                AppIcon(symbol: profile.symbol, size: 23)
                    .foregroundStyle(profile.tint)
            }
        }
        .frame(width: 30, height: 30)
    }
}

private struct GlobalProfileIcon: View {
    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                dot
                dot
            }
            GridRow {
                dot
                dot
            }
        }
    }

    private var dot: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .stroke(lineWidth: 2)
            .frame(width: 6, height: 6)
    }
}

private struct ApplicationProfilePickerView: View {
    let subtitle: String

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("选择应用程序")
                    .font(AppTypography.sectionTitle)
                    .offset(y: DeviceDetailLayoutMetrics.applicationPickerTitleOpticalOffset)
                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.primary.opacity(0.60))
            }
            .padding(.horizontal, DeviceDetailLayoutMetrics.applicationPickerHeaderHorizontalPadding)
            .padding(.top, DeviceDetailLayoutMetrics.applicationPickerHeaderTopPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: DeviceDetailLayoutMetrics.applicationPickerHeaderHeight,
                alignment: .topLeading
            )
            .background(AppTheme.elevatedSurface(for: colorScheme))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ApplicationProfilePickerRow(
                        profile: AppProfile.profiles[0],
                        checked: true,
                        fixed: true
                    )
                    .padding(.top, DeviceDetailLayoutMetrics.applicationPickerGlobalTopSpacing)
                    .padding(.bottom, DeviceDetailLayoutMetrics.applicationPickerGlobalBottomSpacing)

                    Rectangle()
                        .fill(AppTheme.separator(for: colorScheme))
                        .frame(height: 1)

                    HStack {
                        Text("所有应用程序")
                            .font(.custom("AvenirNext-DemiBold", size: 14))
                            .offset(y: DeviceDetailLayoutMetrics.applicationPickerSectionTextOpticalOffset)
                        Spacer()
                        AppIcon(symbol: "chevron.up", size: AppIconSize.control)
                            .offset(y: DeviceDetailLayoutMetrics.applicationPickerSectionChevronOpticalOffset)
                    }
                    .padding(.horizontal, 34)
                    .frame(height: DeviceDetailLayoutMetrics.applicationPickerSectionHeight)

                    ForEach(store.availableApplicationProfiles) { profile in
                        ApplicationProfilePickerRow(
                            profile: profile,
                            checked: store.isApplicationProfileEnabled(profile),
                            fixed: false
                        )
                    }
                }
            }
            .scrollIndicators(.visible)
        }
        .background(AppTheme.surface(for: colorScheme))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择应用程序")
    }
}

private struct ApplicationProfilePickerRow: View {
    let profile: AppProfile
    let checked: Bool
    let fixed: Bool

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button {
            guard !fixed else { return }
            store.toggleApplicationProfile(profile)
        } label: {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        checked
                            ? AppTheme.accent(for: colorScheme).opacity(fixed ? 0.44 : 1)
                            : applicationCheckboxBackground
                    )
                    .frame(width: 18, height: 18)
                    .overlay {
                        if checked {
                            AppIcon(symbol: "check", size: 12)
                                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                        }
                    }

                ProfileApplicationIcon(profile: profile)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.primary.opacity(fixed ? 0.52 : 1))

                Text(fixed ? "全局设置" : profile.title)
                    // Brown Pro Regular has a slightly denser stroke than
                    // Avenir Next Regular. Medium is the closer optical match
                    // for the reference application's 14 pt list labels.
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(Color.primary.opacity(fixed ? 0.58 : 1))
                    .lineLimit(1)
                    .offset(y: DeviceDetailLayoutMetrics.applicationPickerRowTextOpticalOffset)

                Spacer()
            }
            // Options+ uses a 48 pt application row with an effective
            // 33 pt leading inset (3.7% list margin + 18 pt row padding).
            // Keeping those two measurements intact prevents the app list
            // from becoming visibly denser than the reference drawer.
            .padding(.horizontal, 33)
            .frame(height: 48)
            .background(hovered && !fixed ? Color.primary.opacity(0.025) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityLabel(fixed ? "全局设置" : profile.title)
        .accessibilityValue(checked ? "已添加" : "未添加")
    }

    private var applicationCheckboxBackground: Color {
        colorScheme == .dark
            ? Color(white: 51 / 255)
            : Color(red: 225 / 255, green: 226 / 255, blue: 227 / 255)
    }
}

private enum GestureTimingKind: String, CaseIterable, Identifiable {
    case hold
    case doubleTap
    case debounce

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hold: "长按触发"
        case .doubleTap: "双击间隔"
        case .debounce: "按键防抖"
        }
    }

    var settingTitle: String {
        switch self {
        case .hold: "触发时间"
        case .doubleTap: "识别间隔"
        case .debounce: "过滤间隔"
        }
    }

    var detail: String {
        switch self {
        case .hold: "按住按键达到设定时间后，执行当前按键的长按动作。"
        case .doubleTap: "两次按下发生在设定间隔内时，执行当前按键的双击动作。"
        case .debounce: "忽略短时间内重复产生的输入，减少蓝牙按键抖动造成的误触。"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .hold: 250...800
        case .doubleTap: 150...500
        case .debounce: 10...100
        }
    }

    var step: Int {
        switch self {
        case .hold, .doubleTap: 25
        case .debounce: 5
        }
    }

    var defaultValue: Int {
        switch self {
        case .hold: 350
        case .doubleTap: 250
        case .debounce: 30
        }
    }

    var presets: [(title: String, value: Int)] {
        switch self {
        case .hold: [("快速", 300), ("标准", 350), ("从容", 550)]
        case .doubleTap: [("紧凑", 200), ("标准", 250), ("宽松", 400)]
        case .debounce: [("灵敏", 15), ("标准", 30), ("稳定", 60)]
        }
    }
}

private struct DeviceGestureSettingsView: View {
    @Binding var selection: GestureTimingKind?

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            // Options+ keeps the product at the same visual scale when moving
            // between Buttons and Point & Scroll. Reuse the button canvas
            // height and top anchor so switching pages no longer makes the
            // remote jump eight percent larger.
            let remoteTop = RemoteCanvasMetrics.productViewportTop
            let remoteHeight = RemoteCanvasMetrics.imageHeight(for: proxy.size.height)
            let remoteWidth = remoteHeight * (500.0 / 1843.0)
            let productScale = RemoteCanvasMetrics.productContentScale
            let remoteCenterX = proxy.size.width / 2 + (selection == nil ? -60 : 0)

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.24 : 0.16))
                    .frame(width: max(remoteWidth * productScale * 1.8, 190), height: 8)
                    .blur(radius: 20)
                    .position(
                        x: remoteCenterX + 22,
                        y: remoteTop + remoteHeight - 2
                    )

                RemoteProductImage()
                    .frame(width: remoteWidth, height: remoteHeight)
                    .scaleEffect(productScale)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        radius: 9,
                        x: 7,
                        y: -6
                    )
                    .position(x: remoteCenterX, y: remoteTop + remoteHeight / 2)

                GestureTimingHotspot()
                    .position(x: remoteCenterX + 30, y: 70)

                GestureTimingHotspot()
                    .position(x: remoteCenterX + 15, y: 260)

                GestureTimingHotspot()
                    .position(x: remoteCenterX + 55, y: 284)

                GestureTimingSummaryCallout(
                    kind: .hold,
                    value: store.holdMilliseconds,
                    selected: selection == .hold,
                    size: CGSize(width: 140.25, height: 120)
                ) {
                    selection = .hold
                }
                .position(x: remoteCenterX + 158.5, y: 108.5)

                GestureTimingSummaryCallout(
                    kind: .doubleTap,
                    value: store.doubleTapMilliseconds,
                    selected: selection == .doubleTap,
                    size: CGSize(width: 124, height: 81)
                ) {
                    selection = .doubleTap
                }
                .position(x: remoteCenterX - 69.5, y: 270.5)

                GestureTimingSummaryCallout(
                    kind: .debounce,
                    value: store.debounceMilliseconds,
                    selected: selection == .debounce,
                    size: CGSize(width: 97, height: 61)
                ) {
                    selection = .debounce
                }
                .position(x: remoteCenterX + 165.5, y: 284)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(
                x: DeviceDetailLayoutMetrics.gestureContentXOffset,
                y: DeviceDetailLayoutMetrics.gestureContentYOffset
            )
        }
    }
}

private struct GestureTimingSummaryCallout: View {
    let kind: GestureTimingKind
    let value: Int
    let selected: Bool
    let size: CGSize
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(AppTypography.body)

                switch kind {
                case .hold:
                    Text("\(kind.settingTitle)：")
                        .font(AppTypography.body)
                    Text("\(value) ms")
                        .font(AppTypography.body)
                    Text("按住后执行")
                        .font(AppTypography.body)
                case .doubleTap:
                    Text("\(kind.settingTitle)：")
                        .font(AppTypography.body)
                    Text("\(value) ms")
                        .font(AppTypography.body)
                case .debounce:
                    Text("间隔 \(value) ms")
                        .font(AppTypography.body)
                }
            }
            .offset(y: -0.5)
            .foregroundStyle(selected ? AppTheme.onAccent(for: colorScheme) : Color.primary)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(
                selected
                    ? AppTheme.accent(for: colorScheme)
                    : (colorScheme == .dark
                        ? AppTheme.surface(for: colorScheme)
                        : AppTheme.canvas(for: colorScheme))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        selected
                            ? AppTheme.accent(for: colorScheme)
                            : (colorScheme == .dark
                                ? AppTheme.separator(for: colorScheme)
                                : Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255)),
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
            radius: 10,
            x: 6,
            y: 6
        )
        .accessibilityLabel(kind.title)
        .accessibilityValue("\(kind.settingTitle) \(value) 毫秒")
        .accessibilityHint("打开详细设置")
    }
}

private struct GestureTimingHotspot: View {
    var body: some View {
        Circle()
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: 18, height: 18)
            .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

private struct GestureTimingSettingsPanel: View {
    let kind: GestureTimingKind

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text(kind.title)
                // Keep the reference's 20 pt CJK glyph width without Avenir
                // Next's taller 27 pt line box. The native system stack paints
                // the same four-character title in the target 80 × 24 pt box.
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 33)
                .padding(.trailing, 32)
                .offset(y: -1)
                .frame(height: 70)
                .background(AppTheme.elevatedSurface(for: colorScheme))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(kind.settingTitle)
                            .font(AppTypography.title)
                            .scaleEffect(y: 20 / 22, anchor: .top)
                            .frame(height: 20, alignment: .topLeading)
                        Spacer()
                        Text("\(currentValue) ms")
                            .font(AppTypography.title.monospacedDigit())
                            .scaleEffect(y: 20 / 22, anchor: .top)
                            .frame(height: 20, alignment: .topTrailing)
                            .foregroundStyle(AppTheme.accent(for: colorScheme))
                    }

                    Slider(
                        value: Binding(
                            get: { Double(currentValue) },
                            set: { setValue(Int($0.rounded())) }
                        ),
                        in: Double(kind.range.lowerBound)...Double(kind.range.upperBound),
                        step: Double(kind.step)
                    )
                    .tint(AppTheme.accent(for: colorScheme))
                    .controlSize(.small)
                    .padding(.top, 14)
                    .accessibilityLabel(kind.settingTitle)
                    .accessibilityValue("\(currentValue) 毫秒")

                    Text("推荐值")
                        .font(AppTypography.title)
                        .scaleEffect(y: 20 / 22, anchor: .top)
                        .frame(height: 20, alignment: .topLeading)
                        .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(kind.presets, id: \.value) { preset in
                            Button {
                                setValue(preset.value)
                            } label: {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(
                                            currentValue == preset.value
                                                ? AppTheme.accent(for: colorScheme)
                                                : Color.primary.opacity(0.12)
                                        )
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            if currentValue == preset.value {
                                                Circle()
                                                    .fill(AppTheme.onAccent(for: colorScheme))
                                                    .frame(width: 6, height: 6)
                                            }
                                        }

                                    Text(preset.title)
                                        .font(AppTypography.bodyMedium)
                                        .scaleEffect(y: 18 / 19, anchor: .top)

                                    Spacer()

                                    Text("\(preset.value) ms")
                                        .font(AppTypography.numeric)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                    .padding(.top, 18)

                    Text("工作方式")
                        .font(AppTypography.title)
                        .scaleEffect(y: 20 / 22, anchor: .top)
                        .frame(height: 20, alignment: .topLeading)
                        .padding(.top, 40)

                    Text(kind.detail)
                        .font(AppTypography.body)
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(y: 38 / 41, anchor: .top)
                        .frame(height: 38, alignment: .topLeading)
                        .padding(.top, 12)

                    Button("恢复默认值") {
                        setValue(kind.defaultValue)
                    }
                    .buttonStyle(InlineActionButtonStyle())
                    .font(AppTypography.bodyMedium)
                    .padding(.top, 28)
                }
                .padding(.leading, 33)
                .padding(.trailing, 32)
                .padding(.top, 31)
                .padding(.bottom, 48)
            }
        }
        .background(AppTheme.surface(for: colorScheme))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title)设置")
    }

    private var currentValue: Int {
        switch kind {
        case .hold: store.holdMilliseconds
        case .doubleTap: store.doubleTapMilliseconds
        case .debounce: store.debounceMilliseconds
        }
    }

    private func setValue(_ value: Int) {
        switch kind {
        case .hold: store.setHoldMilliseconds(value)
        case .doubleTap: store.setDoubleTapMilliseconds(value)
        case .debounce: store.setDebounceMilliseconds(value)
        }
    }
}

private struct DeviceFlowWelcomeView: View {
    let beginSetup: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            FlowDeviceIllustration()
                // Measured against the reference FLOW artwork's saturated
                // pixel bounds (339 × 148 pt at x=522, y=242).
                .scaleEffect(x: 1.277, y: 1.081)
                .offset(x: -10.5, y: -24)
                .frame(width: 390, height: 172)

            Text("欢迎使用 MiCoding Flow")
                .font(.custom("AvenirNext-Bold", size: 32))
                .tracking(-0.4)
                .padding(.top, 15)
                .offset(x: -9.5, y: -3.1)
                .scaleEffect(x: 0.991, y: 1, anchor: .topLeading)

            Text("通过 Flow 顺畅使用和控制多台 Mac。使用 macOS 通用控制，将指针移至屏幕边缘即可切换至另一台 Mac。\n启用接力后，还可以在设备之间复制和粘贴文本、图像或文件。")
                .font(AppTypography.body)
                .foregroundStyle(Color.primary.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .frame(width: 698)
                .padding(.top, -4)
                .offset(x: -13.8, y: -1.5)
                .scaleEffect(x: 1.019, y: 1, anchor: .topLeading)

            Button("设置 FLOW", action: beginSetup)
            .buttonStyle(FlowSetupButtonStyle())
            .padding(.top, 32)
            .offset(x: -11.5, y: -1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 112)
        .offset(
            x: DeviceDetailLayoutMetrics.flowContentXOffset,
            y: DeviceDetailLayoutMetrics.flowContentYOffset
        )
    }
}

private struct DeviceFlowSetupView: View {
    let cancel: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule()
                    .fill(AppTheme.separator(for: colorScheme))
                    .frame(width: 232, height: 2)
                    .position(x: proxy.size.width / 2, y: 210)

                FlowComputerCard(title: "本机", status: "已就绪", ready: true)
                    .position(x: proxy.size.width / 2 - 108, y: 210)

                FlowComputerCard(title: "其他电脑", status: nil, ready: false)
                    .position(x: proxy.size.width / 2 + 108, y: 210)

                FlowSetupChecklist()
                    .position(x: proxy.size.width / 2 + 108, y: 118)

                VStack(spacing: 0) {
                    Text("连接其他电脑")
                        .font(.custom("AvenirNext-Bold", size: 32))
                        .tracking(-0.35)

                    HStack(spacing: 4) {
                        Text("在其他 Mac 上执行上述 3 个步骤，以通过 Flow 连接。")
                            .foregroundStyle(Color.primary.opacity(0.78))
                        Button("需要帮助？") {
                            store.openHandoffSettings()
                        }
                    }
                    .font(AppTypography.body)
                    .buttonStyle(FlowInlineLinkStyle())
                    .padding(.top, 8)

                    Button("继续") {
                        store.openDisplaysSettings()
                    }
                    .buttonStyle(FlowSetupButtonStyle(width: 62))
                    .padding(.top, 26)

                    Button("取消", action: cancel)
                        .buttonStyle(FlowCancelButtonStyle(width: 62))
                        .padding(.top, 10)
                }
                .frame(width: 700)
                .position(x: proxy.size.width / 2, y: 430)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FLOW 设置")
    }
}

private struct FlowComputerCard: View {
    let title: String
    let status: String?
    let ready: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.custom("AvenirNext-Medium", size: 20))

            if let status {
                Text(status)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    }
            }
        }
        .frame(width: 194, height: 110)
        .background(
            ready
                ? AppTheme.surface(for: colorScheme)
                : AppTheme.elevatedSurface(for: colorScheme).opacity(colorScheme == .dark ? 0.58 : 0.52)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(ready ? 0.08 : 0), radius: 10, x: 6, y: 6)
    }
}

private struct FlowSetupChecklist: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("1. 打开通用控制")
                .foregroundStyle(Color.white)
            Text("2. 打开 Wi‑Fi 与蓝牙")
            Text("3. 打开接力")
        }
        .font(AppTypography.supportingMedium)
        .multilineTextAlignment(.center)
        .foregroundStyle(Color.white.opacity(0.58))
        .frame(width: 190, height: 57)
        .background(Color(red: 23 / 255, green: 14 / 255, blue: 46 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(alignment: .leading) {
            FlowChecklistPointer()
                .fill(Color(red: 23 / 255, green: 14 / 255, blue: 46 / 255))
                .frame(width: 8, height: 14)
                .offset(x: -7)
        }
    }
}

private struct FlowChecklistPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct FlowSetupButtonStyle: ButtonStyle {
    var width: CGFloat = 104

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppTheme.onAccent(for: colorScheme))
            .frame(width: width, height: 40)
            .background(
                AppTheme.accent(for: colorScheme)
                    .opacity(configuration.isPressed ? 0.80 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? AppTheme.separator(for: colorScheme)
                            : Color(red: 239 / 255, green: 239 / 255, blue: 239 / 255),
                        lineWidth: 1
                    )
            }
    }
}

private struct FlowCancelButtonStyle: ButtonStyle {
    let width: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppTheme.accent(for: colorScheme))
            .frame(width: width, height: 40)
            .background(
                configuration.isPressed
                    ? AppTheme.accent(for: colorScheme).opacity(0.06)
                    : AppTheme.surface(for: colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
    }
}

private struct FlowInlineLinkStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundStyle(AppTheme.accent(for: colorScheme).opacity(configuration.isPressed ? 0.68 : 1))
            .padding(.vertical, 4)
    }
}

private struct FlowDeviceIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? AppTheme.accent(for: colorScheme).opacity(0.12)
                        : Color(red: 232 / 255, green: 236 / 255, blue: 244 / 255),
                    lineWidth: 13
                )
                .frame(width: 136, height: 136)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.accent(for: colorScheme).opacity(0.08))
                .frame(width: 278, height: 7)
                .offset(y: 47)

            flowLaptop(
                colors: [Color(red: 0.09, green: 0.20, blue: 0.76), Color(red: 0.20, green: 0.31, blue: 0.91)],
                accent: AppTheme.warning
            )
            .offset(x: -82, y: 1)

            flowLaptop(
                colors: [Color(red: 0.92, green: 0.27, blue: 0.33), Color(red: 0.24, green: 0.61, blue: 0.88)],
                accent: AppTheme.mint
            )
            .offset(x: 82, y: 1)

            VStack(spacing: -2) {
                HStack(spacing: -2) {
                    Capsule()
                        .fill(Color(red: 0.32, green: 0.72, blue: 0.45))
                        .frame(width: 12, height: 25)
                        .rotationEffect(.degrees(-33))
                    Capsule()
                        .fill(Color(red: 0.39, green: 0.78, blue: 0.51))
                        .frame(width: 12, height: 25)
                        .rotationEffect(.degrees(33))
                }
                Trapezoid()
                    .fill(Color(red: 0.49, green: 0.55, blue: 0.76))
                    .frame(width: 20, height: 15)
            }
            .offset(y: 39)

            Circle()
                .fill(AppTheme.warning)
                .frame(width: 8, height: 8)
                .offset(x: -40, y: -67)
            Circle()
                .fill(AppTheme.mint)
                .frame(width: 7, height: 7)
                .offset(x: 71, y: 63)
        }
    }

    private func flowLaptop(colors: [Color], accent: Color) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.74 : 0.88))
                .frame(width: 126, height: 78)
                .overlay {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .padding(6)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accent)
                            .frame(width: 10, height: 8)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(.white.opacity(0.82))
                            .frame(width: 8, height: 10)
                    }
                    .padding(.leading, 14)
                    .padding(.top, 14)
                }

            Capsule()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.42 : 0.52))
                .frame(width: 143, height: 7)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 6, y: 4)
    }
}

private struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.15, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.85, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

private struct DeviceSmartActionCard: View {
    let action: SmartAction

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var didRun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                IconTile(symbol: action.symbol, tint: action.tint, size: 40)
                Text("\(action.stepCount) 步")
                    .font(AppTypography.supportingMedium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Text(action.title)
                .font(.custom("AvenirNext-Bold", size: 24))
                .tracking(-0.25)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Text(action.subtitle)
                .font(AppTypography.body)
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineLimit(4)
                .lineSpacing(2)
                .padding(.horizontal, 20)

            Spacer(minLength: 10)

            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(height: 1)

            Button(action: run) {
                HStack(spacing: 7) {
                    AppIcon(symbol: didRun ? "checkmark" : "play.fill", size: AppIconSize.indicator)
                    Text(didRun ? "已运行" : "运行")
                        .font(AppTypography.bodyMedium)
                }
                .foregroundStyle(didRun ? AppTheme.success : AppTheme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(QuietButtonStyle())
        }
        .frame(width: 260, height: 320)
        .background(AppTheme.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 10, x: 4, y: 4)
    }

    private func run() {
        didRun = true
        store.runAction(actionID: action.actionID, title: action.title)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            didRun = false
        }
    }
}

private struct DeviceInformationView: View {
    let device: RemoteDevice
    let showFeatureOverview: () -> Void
    let showPhysicalKeyTest: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmsReset = false
    @State private var confirmsRemoval = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                DeviceSettingsSectionLabel("关于")
                    .offset(y: DeviceDetailLayoutMetrics.informationTopCopyYOffset)

                Text("固件版本 \(store.firmwareVersion ?? "未知")")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 17)
                    .offset(y: DeviceDetailLayoutMetrics.informationTopCopyYOffset)
                Text(deviceStatusText)
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .padding(.top, 9)
                    .offset(y: DeviceDetailLayoutMetrics.informationTopCopyYOffset)

                Button("刷新设备信息") { store.checkDeviceInformation() }
                .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                .disabled(store.connectionState != .connected)
                .padding(.top, 16)
                .offset(y: DeviceDetailLayoutMetrics.informationRefreshButtonYOffset)

                if showsInactiveWarning {
                    DeviceWarningNotice("无法刷新设备信息，因为遥控器处于非活动状态。请唤醒遥控器，并确认蓝牙连接和输入监控权限。")
                        .frame(
                            width: DeviceDetailLayoutMetrics.informationTextWidth,
                            alignment: .leading
                        )
                        .padding(.top, 9)
                        .offset(y: DeviceDetailLayoutMetrics.informationWarningYOffset)
                }

                Text("支持")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(
                        .top,
                        showsInactiveWarning
                            ? DeviceDetailLayoutMetrics.informationPostWarningSpacing
                            : 35.5
                    )
                HStack(spacing: 5) {
                    Text("访问")
                        .deviceSettingsBodyOpticalBounds()
                    Button("MiCoding 支持页面") { openSupportPage() }
                        .buttonStyle(DeviceSettingsInlineActionButtonStyle(xOffset: 0))
                        .scaleEffect(
                            y: DeviceDetailLayoutMetrics.informationSupportLinkVerticalScale,
                            anchor: .top
                        )
                    Text("了解更多信息。")
                        .deviceSettingsBodyOpticalBounds()
                }
                .font(AppTypography.body)
                .padding(.top, 3.5)
                .offset(y: DeviceDetailLayoutMetrics.informationSupportCopyYOffset)

                Text("特性概览")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 33.5)
                    .offset(y: DeviceDetailLayoutMetrics.informationFeatureTitleYOffset)
                HStack(spacing: 22) {
                    Button("启动特性概览", action: showFeatureOverview)
                    Button("测试实体按键", action: showPhysicalKeyTest)
                }
                    .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                    .padding(.top, 6.5)
                    .offset(y: DeviceDetailLayoutMetrics.informationFeatureActionsYOffset)

                if !store.detectedPhysicalKeyIDs.isEmpty {
                    HStack(spacing: 8) {
                        AppIcon(symbol: "checkmark.circle", size: AppIconSize.control)
                            .foregroundStyle(
                                store.detectedPhysicalKeyIDs.count == RemotePhysicalKey.allCases.count
                                    ? AppTheme.success
                                    : AppTheme.accent(for: colorScheme)
                            )
                        Text("本次运行已识别 \(store.detectedPhysicalKeyIDs.count) / \(RemotePhysicalKey.allCases.count) 个实体按键")
                            .font(AppTypography.supportingMedium)
                            .foregroundStyle(Color.primary.opacity(0.72))
                    }
                    .padding(.top, 9)
                }

                DeviceSettingsSectionLabel("通用")
                    .padding(.top, 30)
                    .offset(y: DeviceDetailLayoutMetrics.informationGeneralLabelYOffset)
                HStack(spacing: 16) {
                    Text("输入服务")
                        .font(AppTypography.title)
                        .deviceSettingsTitleOpticalBounds()
                    Spacer()
                    DeviceSettingsToggle(
                        isOn: Binding(
                            get: { store.inputServiceEnabled },
                            set: { store.setInputServiceEnabled($0) }
                        ),
                        accessibilityLabel: "输入服务"
                    )
                }
                .frame(minHeight: 48)
                .padding(.top, 27.5)
                .offset(y: DeviceDetailLayoutMetrics.informationGeneralRowYOffset)

                DeviceSettingsSectionLabel("其他")
                    .padding(.top, 30)
                    .offset(y: DeviceDetailLayoutMetrics.informationOtherLabelYOffset)
                Text("设备备份")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 18)
                    .offset(y: DeviceDetailLayoutMetrics.informationBackupTitleYOffset)
                Text("将按键、手势、智能操作和 Actions Ring 配置保存到本地文件。")
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .padding(.top, 6)
                    .offset(y: DeviceDetailLayoutMetrics.informationBackupDescriptionYOffset)
                HStack(spacing: 22) {
                    Button("导出备份") { exportDeviceBackup() }
                    Button("导入备份") { importDeviceBackup() }
                }
                .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                .padding(.top, 11)
                .offset(y: DeviceDetailLayoutMetrics.informationBackupActionsYOffset)

                Text("恢复默认设置")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 30)
                    .offset(y: DeviceDetailLayoutMetrics.informationResetSectionYOffset)
                Text("将所有应用 Profile 的单击、长按和双击分配恢复为默认。")
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .padding(.top, 6)
                    .offset(y: DeviceDetailLayoutMetrics.informationResetSectionYOffset)
                Button("重置为默认设置") { confirmsReset = true }
                .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                .padding(.top, 11)
                .offset(y: DeviceDetailLayoutMetrics.informationResetSectionYOffset)

                Text("输入后端")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 30)
                Text(store.backendLog)
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .lineLimit(2)
                    .padding(.top, 6)
                Button(store.permissions.inputMonitoringGranted ? "重新启动输入服务" : "打开输入监控权限") {
                    if store.permissions.inputMonitoringGranted {
                        store.restartBackend(announce: true)
                    } else {
                        store.requestInputMonitoringPermission()
                        store.openInputMonitoringSettings()
                    }
                }
                .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                .padding(.top, 11)

                Text(store.inputServiceEnabled ? "停用设备" : "启用设备")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 30)
                Text(store.inputServiceEnabled
                    ? "停止监听遥控器输入；设备仍由 macOS 蓝牙保留。"
                    : "重新启用遥控器按键监听服务。")
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .padding(.top, 6)
                Button(store.inputServiceEnabled ? "停用设备" : "启用设备") {
                    store.setInputServiceEnabled(!store.inputServiceEnabled)
                    store.showToast(store.inputServiceEnabled ? "设备输入服务已启用" : "设备输入服务已停用")
                }
                .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                .padding(.top, 11)

                Text("移除设备")
                    .font(AppTypography.title)
                    .deviceSettingsTitleOpticalBounds()
                    .padding(.top, 30)
                Text("停止由 MiCoding 管理并从设备首页移除；现有按键配置会保留。")
                    .font(AppTypography.body)
                    .deviceSettingsBodyOpticalBounds()
                    .foregroundStyle(Color.primary.opacity(0.76))
                    .padding(.top, 6)
                Button("从 MiCoding 移除设备") { confirmsRemoval = true }
                    .buttonStyle(DeviceSettingsInlineActionButtonStyle())
                    .foregroundStyle(Color.red.opacity(0.86))
                    .padding(.top, 11)
                    .padding(.bottom, 48)
                }
                .frame(width: DeviceDetailLayoutMetrics.informationContentWidth, alignment: .leading)
                .padding(.leading, DeviceDetailLayoutMetrics.informationLeadingPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height + DeviceDetailLayoutMetrics.informationViewportExtension,
                alignment: .top
            )
            .offset(y: DeviceDetailLayoutMetrics.informationYOffset)
        }
        .alert("恢复默认按键设置？", isPresented: $confirmsReset) {
            Button("取消", role: .cancel) {}
            Button("恢复默认", role: .destructive) { store.resetDeviceConfiguration() }
        } message: {
            Text("所有应用 Profile 的单击、长按和双击分配都会被清除。")
        }
        .confirmationDialog(
            "从 MiCoding 移除设备？",
            isPresented: $confirmsRemoval,
            titleVisibility: .visible
        ) {
            Button("移除并打开蓝牙设置", role: .destructive) {
                store.removeManagedDevice()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("按键配置会保留。若要取消系统配对，请在 macOS 蓝牙设置中选择“忽略此设备”。")
        }
    }

    private func openSupportPage() {
        guard let url = URL(string: "https://github.com/zhangtuansia/MiCoding#readme") else { return }
        NSWorkspace.shared.open(url)
    }

    private func exportDeviceBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "保存 Xiaomi Remote 2 Pro 的本地配置备份"
        panel.nameFieldStringValue = "MiCoding-Xiaomi-Remote-2-Pro-Backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.makeDeviceBackupData().write(to: url, options: .atomic)
            store.showToast("设备配置已导出")
        } catch {
            store.showToast("导出失败：\(error.localizedDescription)")
        }
    }

    private func importDeviceBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择 MiCoding 设备配置备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.restoreDeviceBackupData(Data(contentsOf: url))
            store.showToast("设备配置已恢复")
        } catch {
            store.showToast("导入失败：\(error.localizedDescription)")
        }
    }

    private var deviceStatusText: String {
        guard store.devicePresent else { return "设备未连接" }
        guard let batteryLevel = store.batteryLevel else {
            return "设备已连接 · 电量未上报"
        }
        return "设备已连接 · 电量 \(batteryLevel)%"
    }

    private var showsInactiveWarning: Bool {
        store.connectionState != .connected || !store.inputServiceEnabled
    }
}

private struct DeviceSettingsSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AppTypography.bodyMedium)
            .deviceSettingsBodyOpticalBounds()
            .foregroundStyle(Color.primary.opacity(0.34))
    }
}

private extension View {
    func deviceSettingsBodyOpticalBounds() -> some View {
        scaleEffect(
            y: DeviceDetailLayoutMetrics.informationBodyOpticalScale,
            anchor: .top
        )
    }

    func deviceSettingsTitleOpticalBounds() -> some View {
        scaleEffect(
            y: DeviceDetailLayoutMetrics.informationTitleOpticalScale,
            anchor: .top
        )
    }
}

private struct DeviceSettingsInlineActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    var xOffset = DeviceDetailLayoutMetrics.informationInlineActionXOffset

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundStyle(
                AppTheme.accent(for: colorScheme).opacity(
                    isEnabled ? (configuration.isPressed ? 0.62 : 1) : 0.36
                )
            )
            .padding(.horizontal, 5)
            .frame(height: 27)
            .background(
                AppTheme.accent(for: colorScheme)
                    .opacity(isEnabled && configuration.isPressed ? 0.10 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.radiusSmall, style: .continuous))
            .offset(x: xOffset)
    }
}

private struct DeviceWarningNotice: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(AppTypography.body)
            .foregroundStyle(warningText)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warningBackground)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var warningText: Color {
        colorScheme == .dark
            ? Color(red: 0.90, green: 0.72, blue: 0.42)
            : Color(red: 119 / 255, green: 83 / 255, blue: 21 / 255)
    }

    private var warningBackground: Color {
        colorScheme == .dark
            ? AppTheme.warning.opacity(0.12)
            : Color(red: 1, green: 243 / 255, blue: 221 / 255)
    }

    @Environment(\.colorScheme) private var colorScheme
}

private struct DeviceSettingsToggle: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(
                    isOn
                        ? AppTheme.accent(for: colorScheme)
                        : Color.primary.opacity(colorScheme == .dark ? 0.28 : 0.20)
                )
                .frame(width: 28, height: 16)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(AppTheme.primarySurface(for: colorScheme))
                        .frame(width: 12, height: 12)
                        .padding(2)
                }
        }
        .buttonStyle(QuietButtonStyle())
        .frame(
            width: DeviceDetailLayoutMetrics.informationToggleHitWidth,
            height: DeviceDetailLayoutMetrics.informationToggleHitHeight
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

private struct DeviceSettingsRow<Trailing: View>: View {
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
        .frame(minHeight: 48)
    }
}
