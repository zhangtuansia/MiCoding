import SwiftUI

private enum ActionsRingTheme {
    static func canvas(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 26 / 255) : AppTheme.canvas(for: scheme)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : AppTheme.surface(for: scheme)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 77 / 255) : Color.black.opacity(0.10)
    }

    static func paneDivider(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 51 / 255) : AppTheme.separator(for: scheme)
    }
}

enum ActionsRingEditorLayoutMetrics {
    static let paneWidth: CGFloat = 787
    static let headerHeight: CGFloat = 96
    static let headerTitleTracking: CGFloat = 1.03
    static let headerTitleVerticalScale: CGFloat = 1.026
    static let headerTitleYOffset: CGFloat = 1.5
    static let profileCenterX: CGFloat = 669.5
    static let profileUnderlineWidth: CGFloat = 38.5
    static let addProfileCenterX: CGFloat = 722.5
    static let mediumOrbitRadius: CGFloat = 75
    static let actionLibraryHeaderHeight: CGFloat = 73
    static let actionGroupHeight: CGFloat = 42
    static let actionGroupGap: CGFloat = 8
    // Direct AX comparison against the 1180 x 760 reference window leaves a
    // residual 0.35 pt hosting offset after the titlebar is accounted for.
    static let rootVerticalOffset: CGFloat = -4.35
    // The overview intentionally hides the editable detail behind a heavily
    // defocused preview. At 6 pt the node silhouettes match the reference
    // without softening the independent call-to-action layered above it.
    static let overviewPreviewBlurRadius: CGFloat = 6
    static let overviewCallToActionFontSize: CGFloat = 14
}

struct ActionsRingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if store.editsActionsRing {
                ActionsRingEditorView()
            } else {
                ActionsRingOverviewView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ActionsRingTheme.canvas(for: colorScheme))
    }
}

private struct ActionsRingOverviewView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            ActionsRingHeader()

            HStack(spacing: 0) {
                ActionsRingSidebar()
                    .frame(width: 250)

                Group {
                    if store.actionsRingSettingsSelected {
                        ActionsRingSettingsPane()
                    } else {
                        ActionsRingLayoutPane()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ActionsRingHeader: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Button {
                store.closeActionsRing()
            } label: {
                AppIcon(symbol: "arrow.left", size: 24)
                    .scaleEffect(x: 1, y: 0.76)
                    .offset(x: 0.5, y: 2)
                    .frame(width: 46, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("返回")
            .accessibilityLabel("返回")

            Text("Actions Ring")
                .font(AppTypography.latinDisplay)
                .tracking(ActionsRingEditorLayoutMetrics.headerTitleTracking)
                .foregroundStyle(AppTheme.text(for: colorScheme))
                .scaleEffect(
                    x: 1,
                    y: ActionsRingEditorLayoutMetrics.headerTitleVerticalScale,
                    anchor: .topLeading
                )
                .offset(y: ActionsRingEditorLayoutMetrics.headerTitleYOffset)

            Spacer()
        }
        .padding(.leading, 40)
        .padding(.top, 18)
        .frame(height: 98)
        // Options+ draws this page title into the transparent titlebar band;
        // the rest of the Actions Ring canvas already matches vertically.
        .offset(y: -33)
    }
}

private struct ActionsRingSidebar: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ActionsRingSidebarButton(
                title: "布局",
                selected: !store.actionsRingSettingsSelected,
                dotted: true,
                symbol: nil
            ) {
                store.selectActionsRingSettings(false)
            }

            ActionsRingSidebarButton(
                title: "设置",
                selected: store.actionsRingSettingsSelected,
                dotted: false,
                symbol: "list.bullet"
            ) {
                store.selectActionsRingSettings(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 47)
        .offset(y: -43)
    }
}

private struct ActionsRingSidebarButton: View {
    let title: String
    let selected: Bool
    let dotted: Bool
    let symbol: String?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if dotted {
                    ActionsRingDottedIcon(
                        color: selected
                            ? AppTheme.onAccent(for: colorScheme)
                            : Color.primary
                    )
                        .frame(width: 24, height: 24)
                        .scaleEffect(0.95)
                } else if symbol != nil {
                    ActionsRingSettingsIcon(
                        color: selected
                            ? AppTheme.onAccent(for: colorScheme)
                            : Color.primary
                    )
                        .frame(width: 24, height: 24)
                }

                AppTypography.actionsRingNavigationText(title)
                    .fixedSize()
            }
            .offset(x: 3, y: dotted ? 1.5 : 2.5)
            .foregroundStyle(selected ? AppTheme.onAccent(for: colorScheme) : Color.primary)
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .frame(width: 93, height: 40)
            .background(selected ? AppTheme.accent(for: colorScheme) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
    }
}

private struct ActionsRingLayoutPane: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ActionsRingBlurredOverviewPreview(actions: store.actionsRingActions)
            .frame(width: 470, height: 470)

            Button {
                store.editActionsRing()
            } label: {
                HStack(spacing: 4) {
                    Text("自定义 RING")
                        .font(
                            .custom(
                                "AvenirNext-DemiBold",
                                size: ActionsRingEditorLayoutMetrics.overviewCallToActionFontSize
                            )
                        )
                        .offset(y: 0.5)
                    AppIcon(symbol: "arrow.right", size: 17)
                        .scaleEffect(x: 1.45, y: 1.18)
                        .offset(x: -0.5)
                        .frame(width: 32, height: 35)
                }
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .frame(width: 202, height: 64)
                .background(AppTheme.accent(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(QuietButtonStyle())
            .shadow(
                color: Color(red: 55 / 255, green: 32 / 255, blue: 111 / 255).opacity(0.30),
                radius: 8,
                y: 4
            )
            .offset(y: 114)
            .accessibilityLabel("自定义 Actions Ring")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -47, y: -29)
    }
}

/// `View.blur` on macOS leaves native button-backed symbols sharp even when
/// their surrounding SwiftUI shadows are blurred. Resolve the complete preview
/// as one Canvas symbol and apply the filter while drawing that raster layer so
/// the overview matches the deliberately out-of-focus Options+ poster.
private struct ActionsRingBlurredOverviewPreview: View {
    let actions: [RemoteAction?]

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard let preview = context.resolveSymbol(id: 0) else { return }
            context.addFilter(
                .blur(radius: ActionsRingEditorLayoutMetrics.overviewPreviewBlurRadius)
            )
            context.draw(
                preview,
                at: CGPoint(x: size.width / 2, y: size.height / 2),
                anchor: .center
            )
        } symbols: {
            ActionsRingOrbit(
                actions: actions,
                selectedIndex: nil,
                radius: 152,
                showsLabels: false,
                colorful: true,
                action: { _ in },
                dropActionID: nil,
                clear: nil
            )
            .frame(width: 470, height: 470)
            .tag(0)
        }
    }
}

private struct ActionsRingSettingsPane: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSupportPage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("通用")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.5)
                .scaleEffect(x: 1, y: 0.895, anchor: .topLeading)
                .foregroundStyle(Color.secondary.opacity(0.72))

            Text("支持")
                .font(.system(size: 16, weight: .regular))
                .tracking(0.5)
                .scaleEffect(x: 1, y: 0.91, anchor: .topLeading)
                .padding(.top, 25)

            HStack(spacing: 4) {
                Text("访问")
                    .tracking(2.5)
                    .scaleEffect(x: 1, y: 0.947, anchor: .topLeading)
                Button("Actions Ring 支持页面") {
                    showsSupportPage = true
                }
                .buttonStyle(QuietButtonStyle())
                .foregroundStyle(AppTheme.accent(for: colorScheme))
                .tracking(0.18)
                .scaleEffect(x: 1, y: 0.947, anchor: .topLeading)
                Text("了解更多信息。")
                    .tracking(1.875)
                    .scaleEffect(x: 1, y: 0.947, anchor: .topLeading)
            }
            .font(AppTypography.body)
            .foregroundStyle(Color.primary.opacity(0.7))
            .padding(.top, 10)

            Text("特性概览")
                .font(.system(size: 16, weight: .regular))
                .tracking(0.25)
                .scaleEffect(x: 1, y: 0.91, anchor: .topLeading)
                .padding(.top, 33)

            Button("启动特性概览") {
                showsSupportPage = true
            }
            .buttonStyle(QuietButtonStyle())
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.accent(for: colorScheme))
            .padding(.horizontal, 5.5)
            .padding(.vertical, 4)
            .padding(.top, 9)
            .offset(x: -6)

            Text("外观")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.5)
                .scaleEffect(x: 1, y: 0.947, anchor: .topLeading)
                .foregroundStyle(Color.secondary.opacity(0.72))
                .padding(.top, 31)

            Text("尺寸")
                .font(.system(size: 16, weight: .regular))
                .tracking(0.5)
                .scaleEffect(x: 1, y: 0.91, anchor: .topLeading)
                .padding(.top, 25)

            Text("设置 Actions Ring 的显示尺寸")
                .font(AppTypography.body)
                .scaleEffect(x: 1, y: 0.895, anchor: .topLeading)
                .padding(.top, 11)

            VStack(alignment: .leading, spacing: 15) {
                ForEach(ActionsRingSize.allCases) { size in
                    Button {
                        store.setActionsRingSize(size)
                    } label: {
                        HStack(spacing: 17.5) {
                            ZStack {
                                Circle()
                                    .fill(
                                        store.actionsRingSize == size
                                            ? AppTheme.accent(for: colorScheme)
                                            : Color.primary.opacity(0.10)
                                    )
                                    .frame(width: 18, height: 18)
                                if store.actionsRingSize == size {
                                    Circle()
                                        .fill(AppTheme.onAccent(for: colorScheme))
                                        .frame(width: 5, height: 5)
                                }
                            }

                            Text(size.title)
                                .font(AppTypography.body)
                                .scaleEffect(x: 1, y: 0.895, anchor: .topLeading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.leading, 8.5)
            .padding(.top, 23.75)

            Spacer()
        }
        .frame(width: 440, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 39)
        .offset(x: 52)
        .sheet(isPresented: $showsSupportPage) {
            ActionsRingSupportView {
                showsSupportPage = false
                store.editActionsRing()
            }
            .environmentObject(store)
        }
    }
}

struct ActionsRingSupportView: View {
    let edit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                IconTile(symbol: "square.grid.2x2", tint: AppTheme.purple, size: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text("使用 Actions Ring")
                        .font(AppTypography.pageTitle)
                    Text("把常用操作放进八个方向，在任意应用中快速调用。")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    AppIcon(symbol: "xmark", size: AppIconSize.control)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("关闭")
            }

            VStack(spacing: 0) {
                supportRow(
                    number: "1",
                    title: "分配显示动作环",
                    detail: "在设备按键页选择一个按键，并把“显示 Actions Ring”分配给单击、长按或双击。"
                )
                Divider().opacity(0.7)
                supportRow(
                    number: "2",
                    title: "打开并选择操作",
                    detail: "按下已分配的实体按键；动作环会出现在鼠标附近。点按一个方向即可运行对应操作。"
                )
                Divider().opacity(0.7)
                supportRow(
                    number: "3",
                    title: "按应用保存布局",
                    detail: "编辑器顶部可切换全局或应用 Profile，每个 Profile 都能保存独立的八个动作。"
                )
                Divider().opacity(0.7)
                supportRow(
                    number: "4",
                    title: "调整显示尺寸",
                    detail: "在 Actions Ring 设置中选择小、中或大；运行时窗口会自动避开屏幕边缘。"
                )
            }
            .padding(.top, 24)

            HStack {
                Text("提示：按 Esc 可关闭运行中的动作环，不会执行任何操作。")
                    .font(AppTypography.supporting)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("打开编辑器", action: edit)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(.top, 22)
        }
        .padding(30)
        .frame(width: 620, height: 548, alignment: .top)
        .background(AppTheme.canvas(for: colorScheme))
    }

    private func supportRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(AppTypography.label)
                .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                .frame(width: 26, height: 26)
                .background(AppTheme.accent(for: colorScheme))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(AppTypography.title)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }
}

private struct ActionsRingEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                ActionsRingTheme.canvas(for: colorScheme)

                VStack(spacing: 0) {
                    ActionsRingEditorHeader()
                        .frame(height: ActionsRingEditorLayoutMetrics.headerHeight)

                    ActionsRingOrbit(
                        actions: store.actionsRingActions,
                        selectedIndex: store.selectedActionsRingIndex,
                        radius: orbitRadius,
                        showsLabels: true,
                        colorful: false,
                        action: store.selectActionsRingSlot,
                        dropActionID: store.assignActionToActionsRing,
                        clear: store.clearSelectedActionsRingSlot
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 32)
                    .offset(y: 18)

                    HStack(spacing: 12) {
                        AppIcon(symbol: "arrow.uturn.backward.circle", size: 24)
                            .opacity(0.13)
                            .frame(width: 48, height: 48)
                        AppIcon(symbol: "arrow.uturn.forward.circle", size: 24)
                            .opacity(0.13)
                            .frame(width: 48, height: 48)

                        Spacer()

                        Button {
                            if let index = store.selectedActionsRingIndex {
                                store.runActionsRingAction(at: index)
                            }
                        } label: {
                            AppIcon(symbol: "wrench", size: 26)
                                .frame(width: 48, height: 48)
                                .offset(x: 3)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .help("试运行所选操作")

                        Button {
                            store.selectActionsRingSettings(true)
                            store.leaveActionsRingEditor()
                        } label: {
                            AppIcon(symbol: "gearshape", size: 28)
                                .scaleEffect(x: 1.09, y: 0.96)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .help("Actions Ring 设置")
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 15)
                    .frame(height: 72)
                    .offset(y: -15)
                }
            }
            .frame(width: ActionsRingEditorLayoutMetrics.paneWidth)

            Rectangle()
                .fill(ActionsRingTheme.paneDivider(for: colorScheme))
                .frame(width: 1)

            ActionsRingActionLibrary()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ActionsRingTheme.canvas(for: colorScheme))
        }
        .offset(y: ActionsRingEditorLayoutMetrics.rootVerticalOffset)
    }

    private var orbitRadius: CGFloat {
        switch store.actionsRingSize {
        case .small: 68
        case .medium: ActionsRingEditorLayoutMetrics.mediumOrbitRadius
        case .large: 94
        }
    }
}

private struct ActionsRingEditorHeader: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button {
                store.leaveActionsRingEditor()
            } label: {
                AppIcon(symbol: "arrow.left", size: 20)
                    .scaleEffect(x: 1.15, y: 0.88)
                    .offset(x: -1.25, y: -0.25)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(QuietButtonStyle())
            .position(x: 64, y: 37)
            .help("返回 Actions Ring")
            .accessibilityLabel("返回 Actions Ring")

            Menu {
                ForEach(store.profiles) { profile in
                    Button {
                        store.selectActionsRingProfile(profile)
                    } label: {
                        if profile.id == store.selectedActionsRingProfileID {
                            Label(profile.title, systemImage: "checkmark")
                        } else {
                            Text(profile.title)
                        }
                    }
                }
            } label: {
                Color.clear
                    .frame(width: 48, height: 48)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 48, height: 48)
            .overlay {
                ZStack {
                    ActionsRingProfileIcon(color: AppTheme.accent(for: colorScheme))
                        .scaleEffect(x: 1, y: 1.18, anchor: .bottom)
                        .position(x: 24, y: 24)

                    AppIcon(symbol: "chevron.down", size: 9)
                        .foregroundStyle(Color.primary)
                        .position(x: 24, y: 43.5)
                }
                .allowsHitTesting(false)
            }
            .position(x: ActionsRingEditorLayoutMetrics.profileCenterX, y: 32)
            .help("\(store.selectedActionsRingProfile.title) Actions Ring 配置")

            Rectangle()
                .fill(AppTheme.accent(for: colorScheme))
                .frame(width: ActionsRingEditorLayoutMetrics.profileUnderlineWidth, height: 2)
                .position(x: ActionsRingEditorLayoutMetrics.profileCenterX, y: 60)

            Menu {
                let candidates = store.runningApplicationCandidates
                if candidates.isEmpty {
                    Button("没有可添加的运行中应用") {}
                        .disabled(true)
                } else {
                    ForEach(candidates) { profile in
                        Button(profile.title) {
                            store.addActionsRingProfile(profile)
                        }
                    }
                }
            } label: {
                AppIcon(symbol: "plus", size: 24)
                    .scaleEffect(x: 1.106, y: 1.042, anchor: .leading)
                    .offset(y: -0.75)
                    .frame(width: 48, height: 48)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 48, height: 48)
            .position(x: ActionsRingEditorLayoutMetrics.addProfileCenterX, y: 35.25)
            .help("添加配置文件")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActionsRingOrbit: View {
    let actions: [RemoteAction?]
    let selectedIndex: Int?
    let radius: CGFloat
    let showsLabels: Bool
    let colorful: Bool
    let action: (Int) -> Void
    let dropActionID: ((String, Int) -> Bool)?
    let clear: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var dropTargetIndex: Int?

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, ringAction in
                    let angle = Angle.degrees(-90 + Double(index) * 45)
                    let nodePoint = point(center: center, radius: radius, angle: angle)

                    if colorful {
                        // The overview is rendered through
                        // ActionsRingBlurredOverviewPreview, which resolves all
                        // eight nodes into one Canvas layer before filtering it.
                        // Keep the source nodes sharp here to avoid applying the
                        // Gaussian blur twice.
                        ringNode(ringAction, at: index)
                            .padding(20)
                            .compositingGroup()
                            .position(nodePoint)
                            .help(ringAction?.title ?? "空位置")
                    } else {
                        Button {
                            action(index)
                        } label: {
                            ringNode(ringAction, at: index)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .help(ringAction?.title ?? "空位置")
                        .dropDestination(for: String.self) { actionIDs, _ in
                            guard let actionID = actionIDs.first,
                                  let dropActionID else { return false }
                            return dropActionID(actionID, index)
                        } isTargeted: { targeted in
                            dropTargetIndex = targeted ? index : nil
                        }
                        .position(nodePoint)
                    }

                    if showsLabels {
                        AppTypography.actionsRingActionText(ringAction?.title ?? "添加操作")
                            .tracking(labelTracking(for: ringAction))
                            .lineLimit(1)
                            .padding(.horizontal, labelHorizontalPadding(for: ringAction))
                            .frame(height: 35)
                            .background(ActionsRingTheme.surface(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                            .shadow(color: .black.opacity(0.10), radius: 5, x: 4, y: 4)
                            .position(point(center: center, radius: radius + 69, angle: angle))
                            .offset(labelOffset(at: index))
                            .allowsHitTesting(false)
                    }
                }

                Button {
                    clear?()
                } label: {
                    Group {
                        if colorful {
                            Circle()
                                .fill(Color.primary.opacity(0.45))
                                .frame(width: 8, height: 8)
                        } else {
                            AppIcon(symbol: "xmark", size: 10)
                                .foregroundStyle(Color.primary.opacity(0.56))
                                .frame(width: 24, height: 24)
                                .background(Color.primary.opacity(0.06))
                        }
                    }
                        .clipShape(Circle())
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(selectedIndex == nil || clear == nil)
                .position(center)
                .help("移除所选操作")
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }

    private func ringNode(_ ringAction: RemoteAction?, at index: Int) -> some View {
        ZStack {
            if colorful && [0, 1, 2, 6].contains(index) {
                Capsule()
                    .fill(overviewTint(for: ringAction, at: index))
                    .overlay {
                        Capsule().fill(Color.black.opacity(0.34))
                    }
                    .frame(width: 58, height: index == 0 ? 20 : 28)
                    .rotationEffect(.degrees(-90 + Double(index) * 45))
                    .offset(
                        x: cos(Angle.degrees(-90 + Double(index) * 45).radians) * 30,
                        y: sin(Angle.degrees(-90 + Double(index) * 45).radians) * 30
                    )
            }

            Circle()
                .fill(nodeFill(for: ringAction, at: index))
                .frame(width: nodeDiameter, height: nodeDiameter)
                .shadow(
                    color: colorful
                        ? overviewTint(for: ringAction, at: index).opacity(0.78)
                        : .clear,
                    radius: colorful ? 10 : 0
                )
                .overlay {
                    if selectedIndex == index {
                        Circle()
                            .stroke(AppTheme.accent(for: colorScheme), lineWidth: 4)
                            .padding(-5)
                    } else if dropTargetIndex == index {
                        Circle()
                            .stroke(AppTheme.accent(for: colorScheme), lineWidth: 3)
                            .padding(-4)
                    }
                }

            if let ringAction {
                ActionsRingSlotIcon(
                    action: ringAction,
                    size: colorful ? 34 : 20,
                    color: colorful ? overviewIconTint(at: index) : .white
                )
                .opacity(colorful ? 0.72 : 1)
            } else {
                AppIcon(symbol: "plus", size: 18)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func labelOffset(at index: Int) -> CGSize {
        let referenceOffsets: [CGSize] = [
            CGSize(width: -0.25, height: 3.25),
            CGSize(width: 15, height: 9),
            CGSize(width: 11, height: 1.25),
            CGSize(width: 39.5, height: -10.5),
            CGSize(width: -0.5, height: -8),
            CGSize(width: -20.25, height: -10.5),
            CGSize(width: 6, height: -0.5),
            CGSize(width: -4.5, height: 9)
        ]
        return referenceOffsets.indices.contains(index) ? referenceOffsets[index] : .zero
    }

    private func labelHorizontalPadding(for action: RemoteAction?) -> CGFloat {
        switch action?.id {
        case "launch-finder", "launch-notes", "emoji-picker": 10
        case "explore-ai": 9
        case "lock": 12
        case "launch-micoding": 8
        default: 11
        }
    }

    private func labelTracking(for action: RemoteAction?) -> CGFloat {
        switch action?.id {
        case "play-pause": 0.375
        case "screenshot": 0.17
        case "lock": 0.25
        default: 0
        }
    }

    private var nodeDiameter: CGFloat {
        colorful ? 90 : 42
    }

    private func nodeFill(for action: RemoteAction?, at index: Int) -> AnyShapeStyle {
        guard colorful else { return AnyShapeStyle(Color.black) }
        return AnyShapeStyle(overviewTint(for: action, at: index))
    }

    private func overviewTint(for action: RemoteAction?, at index: Int) -> Color {
        let referencePalette: [Color] = [
            Color(white: 0.22),
            Color(red: 0.29, green: 0.00, blue: 0.13),
            Color(red: 0.00, green: 0.95, blue: 0.45),
            Color(red: 0.03, green: 0.38, blue: 0.94),
            Color(white: 0.23),
            Color(red: 0.00, green: 0.18, blue: 0.29),
            Color(red: 0.01, green: 0.00, blue: 0.35),
            Color(red: 0.18, green: 0.00, blue: 0.00)
        ]
        guard referencePalette.indices.contains(index) else {
            return action?.tint ?? Color.gray
        }
        return referencePalette[index]
    }

    private func overviewIconTint(at index: Int) -> Color {
        let referencePalette: [Color] = [
            .white,
            Color(red: 1.00, green: 0.18, blue: 0.43),
            .black,
            .white,
            .white,
            Color(red: 0.20, green: 0.70, blue: 1.00),
            Color(red: 0.66, green: 0.65, blue: 1.00),
            Color(red: 1.00, green: 0.58, blue: 0.00)
        ]
        return referencePalette.indices.contains(index) ? referencePalette[index] : .white
    }

}

private struct ActionsRingSlotIcon: View {
    let action: RemoteAction
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            switch action.id {
            case "play-pause":
                AppIcon(symbol: "play.fill", size: size)
            case "launch-finder":
                ActionsRingFinderIcon()
                    .frame(width: size, height: size)
            case "lock":
                ZStack(alignment: .topTrailing) {
                    AppIcon(symbol: "monitor", size: size)
                    AppIcon(symbol: "lock", size: size * 0.42)
                        .padding(.top, -size * 0.08)
                        .padding(.trailing, -size * 0.08)
                }
                .frame(width: size, height: size)
            default:
                AppIcon(symbol: action.symbol, size: size)
            }
        }
        .foregroundStyle(color)
    }
}

private struct ActionsRingFinderIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let bounds = CGRect(x: 2 * scale, y: 2 * scale, width: 20 * scale, height: 20 * scale)
            let stroke = StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round, lineJoin: .round)
            context.stroke(
                Path(roundedRect: bounds, cornerRadius: 4 * scale),
                with: .color(.white),
                style: stroke
            )

            var divider = Path()
            divider.move(to: CGPoint(x: 12 * scale, y: 2 * scale))
            divider.addCurve(
                to: CGPoint(x: 10.5 * scale, y: 13 * scale),
                control1: CGPoint(x: 12 * scale, y: 6 * scale),
                control2: CGPoint(x: 10.5 * scale, y: 9 * scale)
            )
            context.stroke(divider, with: .color(.white), style: stroke)

            var face = Path()
            face.move(to: CGPoint(x: 5.5 * scale, y: 8 * scale))
            face.addLine(to: CGPoint(x: 7.5 * scale, y: 8 * scale))
            face.move(to: CGPoint(x: 16.5 * scale, y: 8 * scale))
            face.addLine(to: CGPoint(x: 18.5 * scale, y: 8 * scale))
            face.move(to: CGPoint(x: 6 * scale, y: 15 * scale))
            face.addCurve(
                to: CGPoint(x: 18 * scale, y: 14 * scale),
                control1: CGPoint(x: 9 * scale, y: 19 * scale),
                control2: CGPoint(x: 15 * scale, y: 18 * scale)
            )
            context.stroke(face, with: .color(.white), style: stroke)
        }
    }
}

private struct ActionsRingActionLibrary: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var expandedGroup: RingActionGroup?
    @State private var selectedGroup: RingActionGroup?
    @State private var showsSearch = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Menu {
                    Button("所有操作") {
                        selectedGroup = nil
                        expandedGroup = nil
                    }

                    Divider()

                    ForEach(RingActionGroup.allCases) { group in
                        Button(group.title) {
                            selectedGroup = group
                            expandedGroup = group
                        }
                    }
                } label: {
                    Color.clear
                        .frame(width: 129.5, height: 49)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 129.5, height: 49)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(ActionsRingTheme.border(for: colorScheme), lineWidth: 1)
                }
                .overlay(alignment: .leading) {
                    HStack(spacing: 8) {
                        ActionsRingLibraryIcon()
                            .offset(y: 0.5)
                            .frame(width: 31.5, height: 31.5)
                            .scaleEffect(0.95)
                        Text(selectedGroup?.title ?? "所有操作")
                            .font(AppTypography.body)
                            .lineLimit(1)
                            .offset(y: 0.5)
                    }
                    .padding(.leading, 16.75)
                    .allowsHitTesting(false)
                }
                .fixedSize()
                .help("筛选操作分类")
                .accessibilityLabel("浏览插件和操作类别")

                Spacer()

                Button {
                    store.selectSection(.automations)
                } label: {
                    AppIcon(symbol: "shopping.bag", size: 23)
                        .foregroundStyle(AppTheme.onAccent(for: colorScheme))
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(QuietButtonStyle())
                .help("浏览 Smart Actions")

                Button {
                    showsSearch.toggle()
                    if !showsSearch { searchText = "" }
                } label: {
                    AppIcon(symbol: "magnifyingglass", size: 23)
                        .scaleEffect(0.87)
                        .offset(x: -0.25, y: 0.75)
                        .frame(width: 49, height: 49)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(ActionsRingTheme.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(QuietButtonStyle())
                .help("搜索")
            }
            .padding(.leading, 16)
            .padding(.trailing, 15)
            .padding(.top, 8)
            .padding(.bottom, 17)
            .frame(height: ActionsRingEditorLayoutMetrics.actionLibraryHeaderHeight)
            .background(ActionsRingTheme.surface(for: colorScheme))

            Rectangle()
                .fill(ActionsRingTheme.border(for: colorScheme))
                .frame(height: 1)

            if showsSearch {
                HStack(spacing: 10) {
                    AppIcon(symbol: "magnifyingglass", size: 16)
                        .foregroundStyle(.secondary)
                    TextField("搜索操作", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppTypography.body)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.primary.opacity(0.035))
            }

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: ActionsRingEditorLayoutMetrics.actionGroupGap
                ) {
                    HStack {
                        HStack(spacing: 11) {
                            Text("OS")
                                .font(.custom("AvenirNext-Bold", size: 9))
                                .foregroundStyle(.white)
                                .frame(width: 19, height: 19)
                                .background(Color.primary.opacity(0.88))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                            Text("系统 操作")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Spacer()

                        ActionsRingVerticalEllipsis()
                            .frame(width: 18, height: 18)
                            .offset(x: 7)
                    }
                    .padding(.leading, 11)
                    // Keep the title baseline fixed while matching the first
                    // category card, which starts 2.5 pt lower in Options+.
                    .padding(.bottom, 12.5)
                    .offset(y: -0.5)

                    ForEach(visibleGroups) { group in
                        RingActionGroupRow(
                            group: group,
                            actions: filteredActions(in: group),
                            expanded: expandedGroup == group,
                            toggle: {
                                withAnimation(.easeOut(duration: 0.14)) {
                                    expandedGroup = expandedGroup == group ? nil : group
                                }
                            },
                            select: store.assignActionToActionsRing
                        )
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 28)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private var visibleGroups: [RingActionGroup] {
        selectedGroup.map { [$0] } ?? RingActionGroup.allCases
    }

    private func filteredActions(in group: RingActionGroup) -> [RemoteAction] {
        let actions = group.actions(from: RemoteAction.catalog, installed: store.actionsRingSmartActionCatalog)
        guard !searchText.isEmpty else { return actions }
        return actions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private enum RingActionGroup: String, CaseIterable, Identifiable {
    case media
    case open
    case navigation
    case system
    case mouse
    case keyboard
    case dateAndTime
    case widgets
    case advanced
    case smartActions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: "媒体和音量"
        case .open: "打开"
        case .navigation: "导航"
        case .system: "系统"
        case .mouse: "鼠标"
        case .keyboard: "键盘"
        case .dateAndTime: "日期和时间"
        case .widgets: "小部件"
        case .advanced: "高级"
        case .smartActions: "EASY-SWITCH"
        }
    }

    func actions(from catalog: [RemoteAction], installed: [RemoteAction]) -> [RemoteAction] {
        switch self {
        case .media:
            catalog.filter { $0.category == .media }
        case .open:
            catalog.filter { $0.category == .apps }
        case .navigation:
            catalog.filter { ["browser-back", "browser-forward", "mission-control", "desktop"].contains($0.id) }
        case .system:
            catalog.filter { $0.category == .system && !["browser-back", "browser-forward", "desktop"].contains($0.id) }
        case .mouse:
            catalog.filter { ["copy", "paste", "cut", "select-all"].contains($0.id) }
        case .keyboard:
            catalog.filter { ["enter", "escape", "delete", "undo", "redo", "emoji-picker"].contains($0.id) }
        case .dateAndTime:
            catalog.filter { $0.id == "launch-calendar" }
        case .widgets:
            catalog.filter { ["launch-notes", "screenshot"].contains($0.id) }
        case .advanced:
            catalog.filter { $0.category == .recommended }
        case .smartActions:
            []
        }
    }
}

private struct RingActionGroupRow: View {
    let group: RingActionGroup
    let actions: [RemoteAction]
    let expanded: Bool
    let toggle: () -> Void
    let select: (RemoteAction) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 14) {
                    AppIcon(symbol: expanded ? "chevron.up" : "chevron.down", size: 13)
                    Text(group.title)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 15)
                .frame(height: ActionsRingEditorLayoutMetrics.actionGroupHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())

            if expanded {
                if actions.isEmpty {
                    Text("没有匹配的操作")
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 42)
                        .padding(.vertical, 10)
                } else {
                    ForEach(actions) { action in
                        Button {
                            select(action)
                        } label: {
                            HStack(spacing: 12) {
                                AppIcon(symbol: action.symbol, size: 17)
                                    .foregroundStyle(action.tint)
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                        .font(AppTypography.bodyMedium)
                                    Text(action.subtitle)
                                        .font(AppTypography.supporting)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                AppIcon(symbol: "plus", size: 14)
                                    .foregroundStyle(AppTheme.accent(for: colorScheme))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(QuietButtonStyle())
                        .draggable(action.id)
                    }
                }
            }
        }
        .background(ActionsRingTheme.surface(for: colorScheme))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(ActionsRingTheme.border(for: colorScheme), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct ActionsRingDottedIcon: View {
    var color: Color = .primary

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 3.2, height: 3.2)
                    .offset(y: -8.4)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct ActionsRingSettingsIcon: View {
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            bar(width: 16)
            bar(width: 8)
            bar(width: 12)
        }
        .frame(width: 16, height: 12, alignment: .leading)
        .frame(width: 24, height: 24)
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color)
            .frame(width: width, height: 2)
    }
}

private struct ActionsRingLibraryIcon: View {
    var body: some View {
        VStack(spacing: 3.5) {
            row
            row
        }
        .frame(width: 18.5, height: 18.5)
        .frame(width: 31.5, height: 31.5)
    }

    private var row: some View {
        HStack(spacing: 3.5) {
            square
            square
        }
    }

    private var square: some View {
        RoundedRectangle(cornerRadius: 1.25, style: .continuous)
            .stroke(Color.primary, lineWidth: 1.25)
            .frame(width: 7.5, height: 7.5)
    }
}

private struct ActionsRingProfileIcon: View {
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 2.5) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle()
                            .stroke(color, lineWidth: 1.5)
                            .frame(width: 5.5, height: 5.5)
                    }
                }
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct ActionsRingVerticalEllipsis: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.primary)
                    .frame(width: 3, height: 3)
            }
        }
    }
}
