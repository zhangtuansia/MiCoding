import AppKit
import SwiftUI

extension Notification.Name {
    static let showActionsRingRequested = Notification.Name("MiCoding.ShowActionsRingRequested")
}

@MainActor
final class ActionsRingOverlayInteractionModel: ObservableObject {
    @Published private(set) var scrollSequence = 0
    private(set) var scrollDelta = 0

    func postScroll(deltaY: CGFloat) {
        guard deltaY != 0 else { return }
        scrollDelta = deltaY > 0 ? 1 : -1
        scrollSequence &+= 1
    }
}

@MainActor
final class ActionsRingOverlayController {
    private var panel: ActionsRingPanel?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        actions: [RemoteAction?],
        size: ActionsRingSize,
        onSelect: @escaping (RemoteAction) -> Void,
        onAdjust: @escaping (RemoteAction, Int) -> Void
    ) {
        dismiss()

        let side = Self.panelSide(for: size)
        let panel = ActionsRingPanel(
            contentRect: CGRect(x: 0, y: 0, width: side, height: side),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false

        let interaction = ActionsRingOverlayInteractionModel()
        let content = ActionsRingRuntimeOverlayView(
            actions: actions,
            size: size,
            interaction: interaction,
            close: { [weak self] in self?.dismiss() },
            select: { [weak self] action in
                self?.dismiss()
                onSelect(action)
            },
            adjust: onAdjust
        )
        let hostingView = NSHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        let cursor = NSEvent.mouseLocation
        let visibleFrame = NSScreen.screens.first(where: {
            NSMouseInRect(cursor, $0.frame, false)
        })?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(Self.panelOrigin(
            cursor: cursor,
            side: side,
            visibleFrame: visibleFrame
        ))

        self.panel = panel
        installDismissMonitors(for: panel, interaction: interaction)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    private func installDismissMonitors(
        for panel: NSPanel,
        interaction: ActionsRingOverlayInteractionModel
    ) {
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .keyDown,
            .scrollWheel
        ]

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self, weak panel] event in
            Task { @MainActor in
                guard let self, let panel else { return }
                if event.type == .keyDown, event.keyCode == 53 {
                    self.dismiss()
                } else if event.type == .scrollWheel,
                          panel.frame.contains(NSEvent.mouseLocation) {
                    interaction.postScroll(deltaY: event.scrollingDeltaY)
                } else if event.type != .keyDown,
                          event.type != .scrollWheel,
                          !panel.frame.contains(NSEvent.mouseLocation) {
                    self.dismiss()
                }
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self, weak panel] event in
            guard let self, let panel else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.dismiss()
                return nil
            }
            if event.type == .scrollWheel,
               panel.frame.contains(NSEvent.mouseLocation) {
                interaction.postScroll(deltaY: event.scrollingDeltaY)
                return nil
            }
            if event.type != .keyDown,
               event.type != .scrollWheel,
               !panel.frame.contains(NSEvent.mouseLocation) {
                self.dismiss()
            }
            return event
        }
    }

    static func panelSide(for size: ActionsRingSize) -> CGFloat {
        switch size {
        // The panel is transparent. Give the outward-facing labels enough
        // room so AppKit does not crop them at the window boundary.
        case .small: 440
        case .medium: 520
        case .large: 620
        }
    }

    static func panelOrigin(
        cursor: CGPoint,
        side: CGFloat,
        visibleFrame: CGRect
    ) -> CGPoint {
        let target = CGPoint(x: cursor.x - side / 2, y: cursor.y - side / 2)
        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - side)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - side)
        return CGPoint(
            x: min(max(target.x, visibleFrame.minX), maximumX),
            y: min(max(target.y, visibleFrame.minY), maximumY)
        )
    }
}

private final class ActionsRingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
struct ActionsRingRuntimeOverlayView: View {
    let actions: [RemoteAction?]
    let size: ActionsRingSize
    let close: () -> Void
    let select: (RemoteAction) -> Void
    let adjust: (RemoteAction, Int) -> Void

    @ObservedObject private var interaction: ActionsRingOverlayInteractionModel

    @State private var hoveredIndex: Int?
    @State private var activeFolderID: String?
    @State private var adjustingActionID: String?
    @State private var adjustmentLevel = 50
    @State private var lastDragStep = 0

    init(
        actions: [RemoteAction?],
        size: ActionsRingSize,
        initialFolderID: String? = nil,
        initialAdjustingActionID: String? = nil,
        interaction: ActionsRingOverlayInteractionModel = ActionsRingOverlayInteractionModel(),
        close: @escaping () -> Void,
        select: @escaping (RemoteAction) -> Void,
        adjust: @escaping (RemoteAction, Int) -> Void = { _, _ in }
    ) {
        self.actions = actions
        self.size = size
        self.close = close
        self.select = select
        self.adjust = adjust
        _interaction = ObservedObject(wrappedValue: interaction)
        _activeFolderID = State(initialValue: initialFolderID)
        _adjustingActionID = State(initialValue: initialAdjustingActionID)
    }

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let visibleActions = displayedActions
            let angleStep = 360 / Double(max(visibleActions.count, 1))

            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)

                ForEach(Array(visibleActions.enumerated()), id: \.offset) { index, action in
                    let angle = Angle.degrees(-90 + Double(index) * angleStep)
                    let isAdjusting = adjustingActionID == action?.id
                    let nodeRadius = radius + (isAdjusting ? adjustmentRadialOffset : 0)
                    let nodePoint = point(center: center, radius: nodeRadius, angle: angle)

                    Button {
                        guard let action else { return }
                        if ActionsRingFolderCatalog.definition(for: action.id) != nil {
                            withAnimation(.easeOut(duration: 0.14)) {
                                hoveredIndex = nil
                                adjustingActionID = nil
                                activeFolderID = action.id
                            }
                        } else if action.actionsRingParameterKind != nil {
                            beginAdjusting(action)
                        } else {
                            select(action)
                        }
                    } label: {
                        runtimeNode(action, at: index)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(action == nil)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                guard let action else { return }
                                handleAdjustmentDrag(action, translation: value.translation.width)
                            }
                            .onEnded { _ in
                                lastDragStep = 0
                            }
                    )
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            hoveredIndex = hovering ? index : nil
                        }
                    }
                    .help(nodeHelp(for: action))
                    .position(nodePoint)
                    .zIndex(isAdjusting ? 20 : 1)

                    if let action, adjustingActionID != action.id {
                        Text(action.title)
                            .font(.custom("AvenirNext-Medium", size: labelSize))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: labelMaxWidth)
                            .frame(height: labelHeight)
                            .background(Color.white.opacity(0.98))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                            .position(
                                labelPoint(center: center, angle: angle)
                            )
                            .allowsHitTesting(false)
                    }
                }

                Button(action: centerAction) {
                    AppIcon(
                        symbol: centerSymbol,
                        size: centerSymbol == "xmark" ? 11 : 13
                    )
                        .foregroundStyle(Color.black.opacity(0.62))
                        .frame(width: centerSize, height: centerSize)
                        .background(Color.white.opacity(0.94))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
                }
                .buttonStyle(QuietButtonStyle())
                .help(centerHelp)
                .position(center)
            }
        }
        .onChange(of: interaction.scrollSequence) { _, _ in
            guard let action = adjustingAction else { return }
            applyAdjustment(action, delta: interaction.scrollDelta)
        }
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Actions Ring")
    }

    private var displayedActions: [RemoteAction?] {
        guard let activeFolderID,
              let folder = ActionsRingFolderCatalog.definition(for: activeFolderID) else {
            return actions
        }
        return folder.actions.map(Optional.some)
    }

    private func centerAction() {
        if adjustingActionID != nil {
            withAnimation(.easeOut(duration: 0.14)) {
                adjustingActionID = nil
                lastDragStep = 0
            }
        } else if activeFolderID != nil {
            withAnimation(.easeOut(duration: 0.14)) {
                hoveredIndex = nil
                activeFolderID = nil
            }
        } else {
            close()
        }
    }

    @ViewBuilder
    private func runtimeNode(_ action: RemoteAction?, at index: Int) -> some View {
        if let action, adjustingActionID == action.id,
           let parameter = action.actionsRingParameterKind {
            HStack(spacing: 8) {
                AppIcon(symbol: "minus", size: 12)
                    .foregroundStyle(.white.opacity(0.82))

                VStack(spacing: 4) {
                    Text(parameter.title)
                        .font(.custom("AvenirNext-DemiBold", size: labelSize))
                        .foregroundStyle(.white)
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { segment in
                            Capsule()
                                .fill(
                                    segment < Int(ceil(Double(adjustmentLevel) / 12.5))
                                        ? AppTheme.purple
                                        : Color.white.opacity(0.22)
                                )
                                .frame(width: adjustmentSegmentWidth, height: 4)
                        }
                    }
                }

                AppIcon(symbol: "plus", size: 12)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, 12)
            .frame(width: adjustmentBubbleWidth, height: bubbleSize)
            .background(Color.black.opacity(0.97))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.purple.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        } else {
            ZStack {
                Circle()
                    .fill(nodeColor(for: action, at: index))
                    .frame(width: bubbleSize, height: bubbleSize)
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 6)

                if let action {
                    AppIcon(symbol: action.symbol, size: iconSize)
                        .foregroundStyle(.white)
                } else {
                    AppIcon(symbol: "plus", size: iconSize - 3)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .scaleEffect(hoveredIndex == index ? 1.08 : 1)
        }
    }

    private var adjustingAction: RemoteAction? {
        guard let adjustingActionID else { return nil }
        return displayedActions.compactMap { $0 }.first(where: { $0.id == adjustingActionID })
    }

    private func beginAdjusting(_ action: RemoteAction) {
        guard action.actionsRingParameterKind != nil else { return }
        withAnimation(.easeOut(duration: 0.14)) {
            adjustingActionID = action.id
            adjustmentLevel = 50
            lastDragStep = 0
        }
    }

    private func handleAdjustmentDrag(_ action: RemoteAction, translation: CGFloat) {
        guard action.actionsRingParameterKind != nil else { return }
        if adjustingActionID != action.id {
            beginAdjusting(action)
        }
        let currentStep = Int(translation / 10)
        let delta = currentStep - lastDragStep
        guard delta != 0 else { return }
        lastDragStep = currentStep
        applyAdjustment(action, delta: delta)
    }

    private func applyAdjustment(_ action: RemoteAction, delta: Int) {
        guard delta != 0, action.actionsRingParameterKind != nil else { return }
        adjustmentLevel = min(max(adjustmentLevel + delta * 5, 0), 100)
        adjust(action, delta)
    }

    private func nodeHelp(for action: RemoteAction?) -> String {
        guard let action else { return "空位置" }
        if action.actionsRingParameterKind != nil {
            return adjustingActionID == action.id
                ? "滚动或左右拖动以调节\(action.title)"
                : "点按后调节\(action.title)"
        }
        return action.title
    }

    private var centerSymbol: String {
        if adjustingActionID != nil { return "xmark" }
        return activeFolderID == nil ? "xmark" : "arrow.left"
    }

    private var centerHelp: String {
        if adjustingActionID != nil { return "结束参数调节" }
        return activeFolderID == nil ? "关闭 Actions Ring" : "返回主 Actions Ring"
    }

    private func nodeColor(for action: RemoteAction?, at index: Int) -> Color {
        if hoveredIndex == index { return AppTheme.purple }
        guard let action else { return Color.black.opacity(0.96) }
        if ActionsRingFolderCatalog.definition(for: action.id) != nil {
            return AppTheme.purple.opacity(0.96)
        }
        return Color.black.opacity(0.96)
    }

    private var radius: CGFloat {
        switch size {
        case .small: 80
        case .medium: 100
        case .large: 120
        }
    }

    private var bubbleSize: CGFloat {
        switch size {
        case .small: 42
        case .medium: 50
        case .large: 58
        }
    }

    private var iconSize: CGFloat { bubbleSize * 0.43 }
    private var centerSize: CGFloat { bubbleSize * 0.56 }
    private var adjustmentBubbleWidth: CGFloat {
        switch size {
        case .small: 132
        case .medium: 154
        case .large: 178
        }
    }
    private var adjustmentSegmentWidth: CGFloat {
        switch size {
        case .small: 5
        case .medium: 6
        case .large: 7.5
        }
    }
    private var adjustmentRadialOffset: CGFloat {
        switch size {
        case .small: 18
        case .medium: 24
        case .large: 30
        }
    }
    private var labelSize: CGFloat { size == .small ? 9 : size == .large ? 12 : 10 }
    private var labelHeight: CGFloat { size == .small ? 22 : size == .large ? 28 : 24 }
    private var labelMaxWidth: CGFloat { size == .small ? 96 : size == .large ? 136 : 108 }
    private var labelGap: CGFloat { size == .small ? 6 : size == .large ? 8 : 7 }

    private func labelPoint(center: CGPoint, angle: Angle) -> CGPoint {
        let horizontalSupport = abs(cos(angle.radians)) * labelMaxWidth / 2
        let verticalSupport = abs(sin(angle.radians)) * labelHeight / 2
        let labelRadius = radius
            + bubbleSize / 2
            + labelGap
            + horizontalSupport
            + verticalSupport
        return point(center: center, radius: labelRadius, angle: angle)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }
}
