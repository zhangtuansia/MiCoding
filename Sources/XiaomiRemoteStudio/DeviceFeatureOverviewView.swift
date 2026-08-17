import Foundation
import SwiftUI

enum FeatureOverviewMetrics {
    static let introProductSize = CGSize(width: 80, height: 293)
    static let tourDeviceCenter = CGPoint(x: 330, y: 349)
    static let tourPanelCenter = CGPoint(x: 879, y: 352.5)
    static let tourSkipCenter = CGPoint(x: 1_117, y: 48.5)
    static let tourPanelSize = CGSize(width: 390, height: 192)
    static let tourPanelHeaderHeight: CGFloat = 77
    static let tourSliderWidth: CGFloat = 323
    static let tourSliderHeight: CGFloat = 16

    static func introProductCenterY(for contentHeight: CGFloat) -> CGFloat {
        contentHeight * 0.31 - 35.5
    }

    static func introCopyCenterY(for contentHeight: CGFloat) -> CGFloat {
        contentHeight * 0.74 + 3
    }
}

struct DeviceFeatureOverviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var page = 0

    private let pageCount = 7

    init(initialPage: Int = 0) {
        _page = State(initialValue: min(max(initialPage, 0), 7))
    }

    var body: some View {
        ZStack {
            if store.featureOverviewStartsInKeyTest {
                FeaturePhysicalKeyTestView {
                    store.dismissFeatureOverview()
                }
                .transition(.opacity)
            } else if page == 0 {
                FeatureOverviewIntro {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        page = 1
                    }
                } onSkip: {
                    store.dismissFeatureOverview()
                }
                .transition(.opacity)
            } else {
                FeatureOverviewTourPage(
                    page: page,
                    pageCount: pageCount,
                    goBack: {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            page = max(0, page - 1)
                        }
                    },
                    goForward: {
                        if page == pageCount {
                            store.dismissFeatureOverview()
                        } else {
                            withAnimation(.easeInOut(duration: 0.20)) {
                                page += 1
                            }
                        }
                    },
                    skip: {
                        store.dismissFeatureOverview()
                    }
                )
                .id(page)
                .transition(.opacity)
            }
        }
        // This tour intentionally uses the light Options+-style canvas even
        // when the rest of MiCoding follows macOS dark mode. Force the full
        // subtree to resolve primary/secondary semantic colors as light too.
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Xiaomi Remote 2 Pro 特性概览")
    }
}

private struct FeatureOverviewIntro: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.purple
                    .ignoresSafeArea()

                RemoteProductImage()
                    // The remote is much narrower than the MX Master, so using
                    // the same bounding-box height makes it dominate the page.
                    // Match the reference device artwork's measured 285pt dark
                    // silhouette while preserving the remote's real aspect.
                    .frame(
                        width: FeatureOverviewMetrics.introProductSize.width,
                        height: FeatureOverviewMetrics.introProductSize.height
                    )
                    .shadow(color: .black.opacity(0.22), radius: 24, y: 18)
                    .position(
                        x: proxy.size.width / 2,
                        y: FeatureOverviewMetrics.introProductCenterY(for: proxy.size.height)
                    )

                VStack(spacing: 0) {
                    Text("XIAOMI REMOTE 2 PRO 简介")
                        .font(.custom("AvenirNext-Bold", size: 32))
                        .tracking(-0.45)

                    Text("点击下方的下一页按钮，了解您的遥控器并快速设置。")
                        .font(.custom("AvenirNext-Regular", size: 14))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.top, 4)

                    Button(action: onNext) {
                        AppIcon(symbol: "arrow.right", size: 25)
                            .foregroundStyle(AppTheme.purple)
                            .frame(width: 68, height: 68)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.09), radius: 12, y: 6)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .padding(.top, 20)
                    .accessibilityLabel("下一页")

                    Button("跳过", action: onSkip)
                        .font(.custom("AvenirNext-Bold", size: 14))
                        .foregroundStyle(Color.white)
                        .buttonStyle(QuietButtonStyle())
                        .padding(.top, 37)
                }
                .foregroundStyle(Color.white)
                .position(
                    x: proxy.size.width / 2,
                    y: FeatureOverviewMetrics.introCopyCenterY(for: proxy.size.height)
                )
            }
        }
    }
}

private struct FeatureOverviewTourPage: View {
    let page: Int
    let pageCount: Int
    let goBack: () -> Void
    let goForward: () -> Void
    let skip: () -> Void

    @EnvironmentObject private var store: AppStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255)
                    .ignoresSafeArea()

                Button("跳过", action: skip)
                    .font(.custom("AvenirNext-Bold", size: 14))
                    .foregroundStyle(AppTheme.purple)
                    .buttonStyle(QuietButtonStyle())
                    .position(
                        x: proxy.size.width - (1_180 - FeatureOverviewMetrics.tourSkipCenter.x),
                        y: FeatureOverviewMetrics.tourSkipCenter.y
                    )

                if page == 1 {
                    FeatureTourRemote(
                        detectedKeyIDs: store.detectedPhysicalKeyIDs,
                        focusedKeyID: store.pressedSlotID,
                        targetKeyIDs: [],
                        neutralTargets: false,
                        productSize: CGSize(width: 143, height: 528)
                    )
                    .frame(width: 390, height: 590)
                    .position(FeatureOverviewMetrics.tourDeviceCenter)

                    FeatureTourTimingPanel()
                        .position(FeatureOverviewMetrics.tourPanelCenter)
                } else {
                    FeatureTourDeviceStage(
                        page: page,
                        detectedKeyIDs: store.detectedPhysicalKeyIDs,
                        focusedKeyID: focusedKeyID
                    )
                    .frame(width: 520, height: 560)
                    .position(FeatureOverviewMetrics.tourDeviceCenter)

                    FeatureOverviewPanel(page: page)
                        .position(FeatureOverviewMetrics.tourPanelCenter)
                }

                FeaturePager(
                    page: page,
                    pageCount: pageCount,
                    goBack: goBack,
                    goForward: goForward
                )
                .position(x: proxy.size.width / 2, y: proxy.size.height - 64)
            }
        }
    }

    private var focusedKeyID: String? {
        if let pressed = store.pressedSlotID { return pressed }
        if page == 3 { return "ok" }
        if page == 4 { return "back" }
        if page == 5 { return "menu" }
        if page == 6 { return "ok" }
        return nil
    }

}

private struct FeaturePhysicalKeyTestView: View {
    let dismiss: () -> Void

    @EnvironmentObject private var store: AppStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255)
                    .ignoresSafeArea()

                Button("完成", action: dismiss)
                    .font(.custom("AvenirNext-Bold", size: 14))
                    .foregroundStyle(AppTheme.purple)
                    .buttonStyle(QuietButtonStyle())
                    .position(
                        x: proxy.size.width - (1_180 - FeatureOverviewMetrics.tourSkipCenter.x),
                        y: FeatureOverviewMetrics.tourSkipCenter.y
                    )

                FeatureTourRemote(
                    detectedKeyIDs: store.detectedPhysicalKeyIDs,
                    focusedKeyID: store.pressedSlotID,
                    targetKeyIDs: Set(RemoteButtonSlot.demoSlots.map(\.id)),
                    neutralTargets: false,
                    productSize: CGSize(width: 143, height: 528)
                )
                .frame(width: 520, height: 560)
                .position(FeatureOverviewMetrics.tourDeviceCenter)

                FeaturePhysicalKeyTestPanel()
                    .position(FeatureOverviewMetrics.tourPanelCenter)

                Button(action: dismiss) {
                    AppIcon(symbol: "checkmark", size: 19)
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(AppTheme.purple)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.purple.opacity(0.30), radius: 4, y: 4)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("完成按键测试")
                .position(x: proxy.size.width - 54, y: proxy.size.height - 64)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Xiaomi Remote 2 Pro 实体按键测试")
    }
}

private struct FeaturePager: View {
    let page: Int
    let pageCount: Int
    let goBack: () -> Void
    let goForward: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if page == 1 {
                Color.clear.frame(width: 64, height: 64)
            } else {
                Button(action: goBack) {
                    AppIcon(symbol: "arrow.left", size: 18)
                        .foregroundStyle(AppTheme.purple)
                        .frame(width: 62, height: 62)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.10), radius: 5, x: 4, y: 4)
                        .frame(width: 64, height: 64)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityLabel("上一页")
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(1...pageCount, id: \.self) { index in
                    Circle()
                        .fill(
                            index == page
                                ? AppTheme.purple
                                : Color(red: 225 / 255, green: 226 / 255, blue: 227 / 255)
                        )
                        .frame(width: index == page ? 12 : 8, height: index == page ? 12 : 8)
                        .frame(width: 20, height: 20)
                }
            }

            Spacer()

            Button(action: goForward) {
                AppIcon(symbol: "arrow.right", size: 19)
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(AppTheme.purple)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.purple.opacity(0.30), radius: 4, y: 4)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityLabel(page == pageCount ? "完成" : "下一页")
        }
        .frame(width: 1_116)
    }
}

private struct FeatureTourTimingPanel: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置长按速度")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 31)
                .frame(height: FeatureOverviewMetrics.tourPanelHeaderHeight)
                .background(Color(red: 236 / 255, green: 236 / 255, blue: 236 / 255))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("长按触发")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text("\(store.holdMilliseconds) ms")
                        .font(.custom("AvenirNext-Regular", size: 18).monospacedDigit())
                        .foregroundStyle(AppTheme.purple)
                }
                .frame(height: 27)

                FeatureTourSlider(
                    value: store.holdMilliseconds,
                    range: 250...800,
                    step: 25,
                    onChange: store.setHoldMilliseconds
                )
                .frame(
                    width: FeatureOverviewMetrics.tourSliderWidth,
                    height: FeatureOverviewMetrics.tourSliderHeight
                )
                .padding(.top, 14)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .frame(
            width: FeatureOverviewMetrics.tourPanelSize.width,
            height: FeatureOverviewMetrics.tourPanelSize.height,
            alignment: .topLeading
        )
        .background(Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 20, x: 20, y: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("设置长按速度")
    }
}

private struct FeatureTourSlider: View {
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    let onChange: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let fraction = normalizedFraction
            let thumbX = proxy.size.width * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 225 / 255, green: 226 / 255, blue: 227 / 255))
                    .frame(height: 4.8)

                Capsule()
                    .fill(AppTheme.purple)
                    .frame(width: thumbX, height: 4.8)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(AppTheme.purple, lineWidth: 5))
                    .position(x: thumbX, y: proxy.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setValue(at: gesture.location.x, width: proxy.size.width)
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("长按触发")
        .accessibilityValue("\(value) 毫秒")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(min(value + step, range.upperBound))
            case .decrement:
                onChange(max(value - step, range.lowerBound))
            @unknown default:
                break
            }
        }
    }

    private var normalizedFraction: CGFloat {
        let span = max(1, range.upperBound - range.lowerBound)
        return CGFloat(value - range.lowerBound) / CGFloat(span)
    }

    private func setValue(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let fraction = min(max(x / width, 0), 1)
        let rawValue = Double(range.lowerBound)
            + Double(fraction) * Double(range.upperBound - range.lowerBound)
        let steppedValue = Int((rawValue / Double(step)).rounded()) * step
        onChange(min(max(steppedValue, range.lowerBound), range.upperBound))
    }
}

private struct FeatureTourDeviceStage: View {
    let page: Int
    let detectedKeyIDs: Set<String>
    let focusedKeyID: String?

    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            FeatureTourRemote(
                detectedKeyIDs: detectedKeyIDs,
                focusedKeyID: focusedKeyID,
                targetKeyIDs: targetKeyIDs,
                neutralTargets: page == 7
            )
            .position(x: 260, y: 280)

            ForEach(callouts) { callout in
                FeatureTourCallout(
                    title: callout.title,
                    subtitle: callout.subtitle,
                    accented: page != 7
                )
                .position(callout.position)
            }

            if page == 6 {
                FeatureGestureArrows()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var targetKeyIDs: Set<String> {
        switch page {
        case 2: ["power", "voice"]
        case 3: ["ok"]
        case 4: ["back"]
        case 5: ["menu"]
        case 6: ["ok"]
        case 7: ["power", "voice", "ok", "back", "home", "menu", "volumeUp", "tv"]
        default: []
        }
    }

    private var callouts: [FeatureTourCalloutModel] {
        switch page {
        case 2:
            return [
                callout(for: "power", fallback: "锁定屏幕", at: CGPoint(x: 112, y: 62)),
                callout(for: "voice", fallback: "Spotlight 效果", at: CGPoint(x: 408, y: 62))
            ]
        case 3:
            return [callout(for: "ok", fallback: "播放 / 暂停", at: CGPoint(x: 104, y: 150))]
        case 4:
            return [callout(for: "back", fallback: "后退", at: CGPoint(x: 102, y: 229))]
        case 5:
            return [callout(for: "menu", fallback: "显示 Actions Ring", at: CGPoint(x: 96, y: 320))]
        case 6:
            return [
                FeatureTourCalloutModel(
                    id: "gesture",
                    title: "手势与连按",
                    subtitle: "方向/确认键",
                    position: CGPoint(x: 102, y: 151)
                )
            ]
        case 7:
            return [
                callout(for: "power", fallback: "锁定屏幕", at: CGPoint(x: 108, y: 58)),
                callout(for: "voice", fallback: "Spotlight 效果", at: CGPoint(x: 410, y: 58)),
                callout(for: "ok", fallback: "播放 / 暂停", at: CGPoint(x: 96, y: 150)),
                callout(for: "back", fallback: "后退", at: CGPoint(x: 92, y: 222)),
                callout(for: "home", fallback: "显示桌面", at: CGPoint(x: 92, y: 280)),
                callout(for: "menu", fallback: "显示 Actions Ring", at: CGPoint(x: 92, y: 338)),
                callout(for: "volumeUp", fallback: "音量控制", at: CGPoint(x: 416, y: 252)),
                callout(for: "tv", fallback: "打开浏览器", at: CGPoint(x: 410, y: 338))
            ]
        default:
            return []
        }
    }

    private func callout(
        for slotID: String,
        fallback: String,
        at position: CGPoint
    ) -> FeatureTourCalloutModel {
        let slot = RemoteButtonSlot.demoSlots.first(where: { $0.id == slotID })
        return FeatureTourCalloutModel(
            id: slotID,
            title: store.action(for: slotID)?.title ?? fallback,
            subtitle: "\(slot?.name ?? "实体")按键",
            position: position
        )
    }
}

private struct FeatureTourCalloutModel: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let position: CGPoint
}

private struct FeatureTourCallout: View {
    let title: String
    let subtitle: String
    let accented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            AppTypography.calloutTitleText(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(AppTypography.calloutDetail)
                .lineLimit(1)
        }
        .foregroundStyle(accented ? Color.white : Color.primary)
        .padding(.horizontal, 12)
        .frame(minWidth: 74, maxWidth: 140, minHeight: 58.4, alignment: .leading)
        .background(accented ? AppTheme.purple : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.black.opacity(accented ? 0.06 : 0.045), lineWidth: 1)
        }
    }
}

private struct FeatureGestureArrows: View {
    var body: some View {
        ZStack {
            gestureArrow("arrow-up", x: 260, y: 8)
            gestureArrow("arrow-down", x: 260, y: 552)
            gestureArrow("arrow-left", x: 170, y: 151)
            gestureArrow("arrow-right", x: 350, y: 151)
        }
    }

    private func gestureArrow(_ symbol: String, x: CGFloat, y: CGFloat) -> some View {
        AppIcon(symbol: symbol, size: 17)
            .foregroundStyle(Color.primary.opacity(0.82))
            .position(x: x, y: y)
    }
}

private struct FeatureTourRemote: View {
    let detectedKeyIDs: Set<String>
    let focusedKeyID: String?
    let targetKeyIDs: Set<String>
    let neutralTargets: Bool
    var productSize = CGSize(width: 143, height: 528)

    var body: some View {
        ZStack {
            RemoteProductImage()
                .frame(width: productSize.width, height: productSize.height)
                .shadow(color: .black.opacity(0.13), radius: 18, y: 11)

            ForEach(RemoteButtonSlot.demoSlots) { slot in
                if targetKeyIDs.contains(slot.id)
                    || detectedKeyIDs.contains(slot.id)
                    || focusedKeyID == slot.id {
                    FeatureTourTarget(
                        detected: detectedKeyIDs.contains(slot.id),
                        focused: focusedKeyID == slot.id,
                        neutral: neutralTargets
                    )
                    .position(markerPosition(for: slot))
                }
            }
        }
        .frame(width: productSize.width, height: productSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Xiaomi Remote 2 Pro 遥控器示意图")
    }

    private func markerPosition(for slot: RemoteButtonSlot) -> CGPoint {
        var x = slot.x * productSize.width
        var y = slot.y * productSize.height
        switch slot.shape {
        case .dpadUp:
            y -= slot.height * productSize.height * 0.29
        case .dpadDown:
            y += slot.height * productSize.height * 0.29
        case .dpadLeft:
            x -= slot.width * productSize.width * 0.29
        case .dpadRight:
            x += slot.width * productSize.width * 0.29
        case .rockerTop:
            y -= slot.height * productSize.height * 0.23
        case .rockerBottom:
            y += slot.height * productSize.height * 0.23
        default:
            break
        }
        return CGPoint(x: x, y: y)
    }
}

private struct FeatureTourTarget: View {
    let detected: Bool
    let focused: Bool
    let neutral: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(detected ? AppTheme.success : Color.clear)

            Circle()
                .strokeBorder(
                    detected ? Color.white : (neutral ? Color.white : AppTheme.purple),
                    lineWidth: detected ? 2 : 2.4
                )

            if detected {
                AppIcon(symbol: "checkmark", size: 8)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: focused ? 18 : 16, height: focused ? 18 : 16)
        .background((neutral ? Color.black.opacity(0.16) : AppTheme.purple.opacity(0.08)).clipShape(Circle()))
        .shadow(color: .black.opacity(0.20), radius: 3, y: 2)
        .animation(.easeOut(duration: 0.12), value: detected)
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

private struct FeatureOverviewPanel: View {
    let page: Int

    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 31)
                .frame(height: FeatureOverviewMetrics.tourPanelHeaderHeight)
                .background(Color(red: 236 / 255, green: 236 / 255, blue: 236 / 255))

            VStack(alignment: .leading, spacing: 0) {
                Text(description)
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .lineSpacing(3)
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                panelContent
                    .padding(.top, contentTopPadding)
            }
            .padding(.horizontal, 31)
            .padding(.top, page == 2 ? 12 : 20)
            .padding(.bottom, page == 2 ? 10 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 390, height: panelHeight)
        .background(Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 20, x: 20, y: 20)
    }

    private var title: String {
        switch page {
        case 2: "按键模式"
        case 3: "自定义确认按键"
        case 4: "自定义返回按钮"
        case 5: "自定义菜单按钮"
        case 6: "手势与连按"
        default: "设置应用程序专用自定义"
        }
    }

    private var description: String {
        switch page {
        case 2: "方向键用于移动焦点，确认键用于执行选择。\n\n长按或双击同一按键可触发额外操作。"
        case 3: "以下为推荐的确认键操作列表。完成初始设置后会有更多选项。"
        case 4: "以下为推荐的返回按钮操作列表。完成初始设置后会有更多选项。"
        case 5: "以下为推荐的菜单按钮操作列表。完成初始设置后会有更多选项。"
        case 6: "为单击、长按和双击分配不同动作，并按您的节奏调整触发时间。"
        default: "为您使用的应用程序自定义遥控器设置，借助预定义 Profile 实现更高效的操作。"
        }
    }

    private var panelHeight: CGFloat {
        switch page {
        case 2:
            return 167
        case 3:
            return 379
        case 4:
            return 453
        case 5:
            return 515
        case 6:
            return 425
        default:
            return 311
        }
    }

    private var contentTopPadding: CGFloat {
        switch page {
        case 2: 0
        case 6: 28
        default: 16
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch page {
        case 2:
            EmptyView()
        case 3:
            actionChoicesContent(
                slotID: "ok",
                actionIDs: ["play-pause", "show-actions-ring", "volume-up", "keyboard-shortcut"]
            )
        case 4:
            actionChoicesContent(
                slotID: "back",
                actionIDs: ["browser-back", "copy", "volume-down", "undo", "keyboard-shortcut", "spotlight", "show-actions-ring"]
            )
        case 5:
            menuChoicesContent
        case 6:
            gestureContent
        default:
            profileContent
        }
    }

    private func actionChoicesContent(
        slotID: String,
        actionIDs: [String]
    ) -> some View {
        let selectedAction = store.action(for: slotID)
        let selectedActionID = selectedAction?.id
        var actions = actionIDs.compactMap { actionID in
            RemoteAction.catalog.first(where: { $0.id == actionID })
        }
        if let selectedAction,
           !actions.contains(where: { $0.id == selectedAction.id }) {
            actions.insert(selectedAction, at: 0)
            if actions.count > actionIDs.count {
                actions.removeLast()
            }
        }

        return VStack(alignment: .leading, spacing: 5) {
            ForEach(actions) { action in
                FeatureChoiceRow(
                    title: action.title,
                    selected: selectedActionID == action.id,
                    showsNewBadge: action.id == "show-actions-ring"
                ) {
                    assignTourAction(action, to: slotID)
                }
            }
        }
    }

    private var menuChoicesContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionChoicesContent(
                slotID: "menu",
                actionIDs: ["screenshot", "paste", "volume-up", "redo", "keyboard-shortcut", "spotlight", "show-actions-ring"]
            )

            HStack(alignment: .top, spacing: 8) {
                AppIcon(symbol: "info", size: 13)
                    .foregroundStyle(Color.primary.opacity(0.62))
                    .padding(.top, 2)
                Text("Actions Ring 可在指针位置打开八方向快捷动作，也可容纳 Smart Actions。")
                    .font(.custom("AvenirNext-Regular", size: 11.5))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.top, 7)
        }
    }

    private func assignTourAction(_ action: RemoteAction, to slotID: String) {
        guard let slot = RemoteButtonSlot.demoSlots.first(where: { $0.id == slotID }) else { return }
        store.selectedTrigger = .tap
        store.selectSlot(slot)
        store.assign(action, to: slot, announce: false)
    }

    private var timingContent: some View {
        VStack(spacing: 12) {
            FeatureTimingRow(title: "长按触发", value: "\(store.holdMilliseconds) ms", fraction: 0.22)
            FeatureTimingRow(title: "双击间隔", value: "\(store.doubleTapMilliseconds) ms", fraction: 0.29)
            FeatureTimingRow(title: "按键防抖", value: "\(store.debounceMilliseconds) ms", fraction: 0.24)
        }
    }

    private var gestureContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeatureGestureMappingRow(
                symbol: "circle.fill",
                gesture: "单击",
                action: store.action(for: "ok", trigger: .tap)?.title ?? "播放 / 暂停"
            )
            FeatureGestureMappingRow(
                symbol: "chevron.down",
                gesture: "按住 \(store.holdMilliseconds) ms",
                action: store.action(for: "ok", trigger: .hold)?.title ?? "显示 Actions Ring"
            )
            FeatureGestureMappingRow(
                symbol: "button.programmable",
                gesture: "双击 \(store.doubleTapMilliseconds) ms",
                action: store.action(for: "ok", trigger: .doubleTap)?.title ?? "调度中心"
            )
            FeatureGestureMappingRow(
                symbol: "slider.horizontal.3",
                gesture: "方向键",
                action: "导航与选择"
            )
            FeatureGestureMappingRow(
                symbol: "arrow.uturn.backward",
                gesture: "返回键",
                action: store.action(for: "back")?.title ?? "后退"
            )
        }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(applicationProfiles.prefix(3)) { profile in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppTheme.purple)
                        .frame(width: 18, height: 18)
                        .overlay(AppIcon(symbol: "checkmark", size: 10).foregroundStyle(.white))

                    ProfileApplicationIcon(profile: profile)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.title)
                            .font(.custom("AvenirNext-DemiBold", size: 13))
                        Text("已经设置")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.success)
                    }
                    Spacer()
                }
            }
        }
    }

    private var applicationProfiles: [AppProfile] {
        let appProfiles = store.profiles.filter { $0.bundleIdentifier != nil }
        return appProfiles.isEmpty
            ? Array(AppProfile.profiles.filter { $0.bundleIdentifier != nil })
            : appProfiles
    }

    private var smartActionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(["打开日历", "打开备忘录", "打开浏览器", "音量减少"].enumerated()), id: \.offset) { index, title in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(AppTypography.numeric)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.045))
                        .clipShape(Circle())
                    Text(title).font(AppTypography.bodyMedium)
                    Spacer()
                }
                .frame(height: 44)
                if index < 3 {
                    Rectangle().fill(Color.black.opacity(0.055)).frame(height: 1).padding(.leading, 38)
                }
            }
        }
    }

    private var actionsRingContent: some View {
        HStack(spacing: 24) {
            FeatureRingPreview()
                .frame(width: 150, height: 150)
            VStack(alignment: .leading, spacing: 11) {
                Label("方向键选择", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                Label("确认键执行", systemImage: "circle.circle")
                Label("返回键关闭", systemImage: "arrow.uturn.backward")
            }
            .font(AppTypography.supportingMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var completionContent: some View {
        VStack(spacing: 0) {
            FeatureStatusRow(title: "蓝牙连接", value: store.connectionState.title, ready: store.connectionState == .connected)
            FeatureStatusRow(title: "遥控器电量", value: store.batteryLevel.map { "\($0)%" } ?? "设备未上报", ready: store.batteryLevel != nil)
            FeatureStatusRow(title: "输入监控", value: store.permissions.inputMonitoringGranted ? "已允许" : "需要允许", ready: store.permissions.inputMonitoringGranted)
            FeatureStatusRow(title: "辅助功能", value: store.permissions.accessibilityGranted ? "已允许" : "需要允许", ready: store.permissions.accessibilityGranted)
        }
    }
}

private struct FeaturePhysicalKeyTestPanel: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("测试实体按键")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 31)
                .frame(height: FeatureOverviewMetrics.tourPanelHeaderHeight)
                .background(Color(red: 236 / 255, green: 236 / 255, blue: 236 / 255))

            VStack(alignment: .leading, spacing: 14) {
                Text("逐个按下遥控器按键。MiCoding 会实时识别，测试期间不会执行已分配动作。")
                    .font(.custom("AvenirNext-Regular", size: 13.5))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Text("已检测 \(store.detectedPhysicalKeyIDs.count) / \(RemotePhysicalKey.allCases.count)")
                        .font(AppTypography.bodyMedium)
                    Spacer()
                    BatteryStatusLabel(
                        level: store.batteryLevel,
                        connected: store.connectionState == .connected
                    )
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.08))
                        Capsule()
                            .fill(isComplete ? AppTheme.success : AppTheme.purple)
                            .frame(width: proxy.size.width * completionFraction)
                    }
                }
                .frame(height: 6)

                if !store.unknownPhysicalUsages.isEmpty {
                    unknownUsageNotice
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 31)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 390, height: store.unknownPhysicalUsages.isEmpty ? 232 : 286)
        .background(Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 240 / 255, green: 240 / 255, blue: 240 / 255), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 20, x: 20, y: 20)
        .animation(.easeOut(duration: 0.18), value: store.unknownPhysicalUsages)
    }

    private var isComplete: Bool {
        store.detectedPhysicalKeyIDs.count == RemotePhysicalKey.allCases.count
    }

    private var completionFraction: CGFloat {
        CGFloat(store.detectedPhysicalKeyIDs.count) / CGFloat(RemotePhysicalKey.allCases.count)
    }

    private var unknownUsageNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                AppIcon(symbol: "info", size: 13)
                    .foregroundStyle(Color.orange)
                Text("检测到尚未映射的按键")
                    .font(AppTypography.supportingMedium)
                Spacer()
                if let date = store.lastUnknownPhysicalUsageDate {
                    Text(date, style: .time)
                        .font(AppTypography.supporting)
                        .foregroundStyle(.secondary)
                }
            }

            Text("原始 Usage：\(unknownUsageText)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.primary.opacity(0.66))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        }
    }

    private var unknownUsageText: String {
        store.unknownPhysicalUsages
            .sorted()
            .map { String(format: "0x%02X", $0) }
            .joined(separator: "  ")
    }
}

private struct FeatureChoiceRow: View {
    let title: String
    let selected: Bool
    let showsNewBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(selected ? Color.white : Color.black.opacity(0.10))
                    .frame(width: 16, height: 16)
                    .overlay {
                        if selected {
                            Circle().fill(AppTheme.purple).frame(width: 5, height: 5)
                        }
                    }
                Text(title)
                    .font(
                        .custom(
                            selected ? "AvenirNext-DemiBold" : "AvenirNext-Regular",
                            size: 14
                        )
                    )
                Spacer()
                if showsNewBadge {
                    Text("新")
                        .font(.custom("AvenirNext-DemiBold", size: 9))
                        .foregroundStyle(AppTheme.success)
                        .padding(.horizontal, 6)
                        .frame(height: 19)
                        .background(Color.green.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: selected ? 48 : 32)
            .background(selected ? AppTheme.purple : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityValue(selected ? "已选择" : "")
    }
}

private struct FeatureGestureMappingRow: View {
    let symbol: String
    let gesture: String
    let action: String

    var body: some View {
        HStack(spacing: 13) {
            AppIcon(symbol: symbol, size: 17)
                .foregroundStyle(Color.primary.opacity(0.84))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(gesture)
                    .font(.custom("AvenirNext-DemiBold", size: 10.5))
                    .foregroundStyle(Color.primary.opacity(0.72))
                Text(action)
                    .font(.custom("AvenirNext-DemiBold", size: 13))
            }
            Spacer()
        }
        .frame(height: 49)
    }
}

private struct FeatureTimingRow: View {
    let title: String
    let value: String
    let fraction: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(AppTypography.bodyMedium)
                Spacer()
                Text(value).font(AppTypography.numeric).foregroundStyle(AppTheme.purple)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.09))
                    Capsule().fill(AppTheme.purple).frame(width: proxy.size.width * fraction)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        .offset(x: max(0, proxy.size.width * fraction - 7))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
        .frame(height: 66)
        .background(Color.black.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct FeatureRingPreview: View {
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) * 0.36
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Color.black.opacity(0.07), lineWidth: 1))
                    .shadow(color: .black.opacity(0.10), radius: 9, y: 4)
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) * .pi / 4 - .pi / 2
                    Circle()
                        .fill(index == 2 ? AppTheme.purple : Color.black.opacity(0.08))
                        .frame(width: 28, height: 28)
                        .position(
                            x: center.x + CGFloat(cos(angle)) * radius,
                            y: center.y + CGFloat(sin(angle)) * radius
                        )
                }
                Circle()
                    .fill(Color.black.opacity(0.78))
                    .frame(width: 34, height: 34)
                    .overlay(AppIcon(symbol: "checkmark", size: 14).foregroundStyle(.white))
            }
        }
    }
}

private struct FeatureStatusRow: View {
    let title: String
    let value: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(symbol: ready ? "checkmark.circle.fill" : "exclamationmark.circle", size: 17)
                .foregroundStyle(ready ? AppTheme.success : AppTheme.warning)
            Text(title).font(AppTypography.bodyMedium)
            Spacer()
            Text(value).font(AppTypography.supportingMedium).foregroundStyle(.secondary)
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.055)).frame(height: 1)
        }
    }
}
