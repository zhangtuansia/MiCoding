import SwiftUI
import UniformTypeIdentifiers

enum RemoteCanvasMetrics {
    // The product and callouts need separate optical origins. The remote's
    // visible alpha bounds sit lower inside its frame than the angled mouse,
    // while using that same origin for labels makes the first row about 37 pt
    // too high. Keeping the stages independent aligns both silhouettes.
    // Live Options+ DOM measurement at 1,180 × 760 places its product image
    // at y=178.39...640.47. The native canvas begins after the 32 pt titlebar
    // and 112 pt detail header, leaving a canvas-relative top of 34.39 pt.
    static let productViewportTop: CGFloat = 34.4
    static let calloutViewportTop: CGFloat = 64
    static let calloutLayoutHeight: CGFloat = 449
    // The premium cutout is 1,784 px tall but its visible alpha bounds are
    // 1,639 px. Scale the device-stage rendering so the real hardware fills
    // the same 462 pt product band as the reference image.
    static let productContentScale: CGFloat = 1_784.0 / 1_639.0
    // The perspective cutout is tightly cropped around 1,532 visible rows in
    // a 1,556 px canvas. It needs only a small transparent-edge correction.
    static let perspectiveContentScale: CGFloat = 1_556.0 / 1_532.0
    static let perspectiveAspectRatio: CGFloat = 388.0 / 1_556.0
    // Restore the real front-face width after the three-quarter render's
    // perspective foreshortening. This lands at the source hardware's roughly
    // 0.27 width/height silhouette without changing the aligned product band.
    static let perspectiveHorizontalScale: CGFloat = 1.10
    static let calloutVerticalPadding: CGFloat = 10
    static let calloutMinimumHeight: CGFloat = 58.4
    static let calloutTextYOffset: CGFloat = 0
    // Keep the two callout columns edge-aligned. Positioning every card by
    // its center made different label widths look as if the controls were
    // drifting around the product.
    static let calloutColumnWidth: CGFloat = 180
    static let calloutInnerGap: CGFloat = 88

    static func imageHeight(for viewportHeight: CGFloat) -> CGFloat {
        min(max(viewportHeight - 154, 440), 462)
    }
}

struct RemoteCanvasView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let productViewportTop = RemoteCanvasMetrics.productViewportTop
            // The reference product occupies y=178...640 in the 760-point
            // window. The native canvas starts below the 32-point titlebar
            // and 112-point header, so its own target is y=34...496. Keep the product
            // at the same 462-point height instead of scaling it to fill all
            // remaining space, which makes the lower controls feel crowded.
            let imageHeight = RemoteCanvasMetrics.imageHeight(for: proxy.size.height)
            let imageWidth = imageHeight * RemoteCanvasMetrics.perspectiveAspectRatio
            let productScale = RemoteCanvasMetrics.perspectiveContentScale
            let imageCenterY = productViewportTop + imageHeight / 2
            let hasTrailingPanel = store.selectedSlot != nil || store.showsApplicationPicker
            let remoteCenterX = proxy.size.width / 2 - (hasTrailingPanel ? 0 : 59)

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.24 : 0.16))
                    .frame(width: max(imageWidth * productScale * 1.8, 190), height: 8)
                    .blur(radius: 20)
                    .position(
                        x: remoteCenterX + 22,
                        y: productViewportTop + imageHeight - 2
                    )

                RemoteProductImage(artwork: .perspective)
                    .frame(width: imageWidth, height: imageHeight)
                    .scaleEffect(
                        x: productScale * RemoteCanvasMetrics.perspectiveHorizontalScale,
                        y: productScale
                    )
                    // A rectangular remote turns the reference mouse's strong
                    // silhouette filter into a gray column. Keep the edge
                    // shadow restrained and carry the weight underneath.
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        radius: 9,
                        x: 7,
                        y: -6
                    )
                    .position(x: remoteCenterX, y: imageCenterY)

                ForEach(RemoteButtonSlot.demoSlots) { slot in
                    let placement = PerspectiveHotspotPlacement.point(for: slot)
                    RemoteHotspot(
                        slot: slot,
                        remoteSize: CGSize(
                            width: imageWidth
                                * productScale
                                * RemoteCanvasMetrics.perspectiveHorizontalScale,
                            height: imageHeight * productScale
                        )
                    )
                        .position(
                            x: remoteCenterX
                                + (placement.x - 0.5)
                                * imageWidth
                                * productScale
                                * RemoteCanvasMetrics.perspectiveHorizontalScale,
                            y: imageCenterY + (placement.y - 0.5) * imageHeight * productScale
                        )
                }

                ForEach(RemoteControlCallout.primaryCallouts) { callout in
                    let activeSlot = callout.activeSlot(selectedSlotID: store.selectedSlotID)
                    let side = HotspotLabelPlacement.side(for: callout.id)
                    let columnHalfWidth = RemoteCanvasMetrics.calloutColumnWidth / 2
                    let labelX = remoteCenterX
                        + side.direction
                        * (RemoteCanvasMetrics.calloutInnerGap + columnHalfWidth)
                    let labelY = RemoteCanvasMetrics.calloutViewportTop
                        + HotspotLabelPlacement.verticalFraction(for: callout.id)
                        * RemoteCanvasMetrics.calloutLayoutHeight

                    HotspotCallout(
                        slot: activeSlot,
                        hardwareTitle: callout.hardwareTitle(for: activeSlot),
                        action: store.action(for: activeSlot.id, trigger: store.selectedTrigger),
                        selected: callout.slotIDs.contains(store.selectedSlotID ?? "")
                    )
                    .frame(
                        width: RemoteCanvasMetrics.calloutColumnWidth,
                        alignment: side.alignment
                    )
                    .position(
                        x: min(
                            max(labelX, columnHalfWidth),
                            proxy.size.width - columnHalfWidth
                        ),
                        y: min(max(labelY, 34), proxy.size.height - 34)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private enum PerspectiveHotspotPlacement {
    static func point(for slot: RemoteButtonSlot) -> CGPoint {
        switch slot.id {
        case "power": CGPoint(x: 0.225, y: 0.083)
        case "voice": CGPoint(x: 0.695, y: 0.083)
        case "up", "left", "ok", "right", "down": CGPoint(x: 0.455, y: 0.255)
        case "back": CGPoint(x: 0.260, y: 0.440)
        case "home": CGPoint(x: 0.260, y: 0.542)
        case "menu": CGPoint(x: 0.260, y: 0.650)
        case "volumeUp", "volumeDown": CGPoint(x: 0.650, y: 0.494)
        case "tv": CGPoint(x: 0.650, y: 0.650)
        default: CGPoint(x: slot.x, y: slot.y)
        }
    }
}

private enum HotspotLabelPlacement {
    enum Side {
        case left
        case right

        var direction: CGFloat { self == .left ? -1 : 1 }
        var alignment: Alignment { self == .left ? .trailing : .leading }
    }

    static func side(for calloutID: String) -> Side {
        switch calloutID {
        case "power", "navigation", "back", "home", "menu": .left
        default: .right
        }
    }

    static func verticalFraction(for calloutID: String) -> CGFloat {
        switch calloutID {
        case "power", "voice": 0.09
        case "navigation": 0.24
        case "back": 0.38
        case "volume": 0.43
        case "home": 0.51
        case "menu", "tv": 0.64
        default: 0.50
        }
    }
}

private struct RemoteControlCallout: Identifiable {
    let id: String
    let primarySlotID: String
    let slotIDs: Set<String>
    let groupedHardwareTitle: String?

    static let primaryCallouts: [RemoteControlCallout] = [
        .init(id: "power", primarySlotID: "power", slotIDs: ["power"], groupedHardwareTitle: nil),
        .init(id: "voice", primarySlotID: "voice", slotIDs: ["voice"], groupedHardwareTitle: nil),
        .init(
            id: "navigation",
            primarySlotID: "ok",
            slotIDs: ["up", "down", "left", "right", "ok"],
            groupedHardwareTitle: "方向/确认键"
        ),
        .init(id: "back", primarySlotID: "back", slotIDs: ["back"], groupedHardwareTitle: nil),
        .init(id: "home", primarySlotID: "home", slotIDs: ["home"], groupedHardwareTitle: nil),
        .init(
            id: "volume",
            primarySlotID: "volumeUp",
            slotIDs: ["volumeUp", "volumeDown"],
            groupedHardwareTitle: "音量按键"
        ),
        .init(id: "menu", primarySlotID: "menu", slotIDs: ["menu"], groupedHardwareTitle: nil),
        .init(id: "tv", primarySlotID: "tv", slotIDs: ["tv"], groupedHardwareTitle: nil)
    ]

    func activeSlot(selectedSlotID: String?) -> RemoteButtonSlot {
        let activeID = selectedSlotID.map { slotIDs.contains($0) ? $0 : primarySlotID } ?? primarySlotID
        return RemoteButtonSlot.demoSlots.first(where: { $0.id == activeID })
            ?? RemoteButtonSlot.demoSlots[0]
    }

    func hardwareTitle(for slot: RemoteButtonSlot) -> String {
        if slot.id == primarySlotID, let groupedHardwareTitle {
            return groupedHardwareTitle
        }
        return "\(slot.name)按键"
    }
}

private struct HotspotCallout: View {
    let slot: RemoteButtonSlot
    let hardwareTitle: String
    let action: RemoteAction?
    let selected: Bool

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button {
            store.selectSlot(slot)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                AppTypography.calloutTitleText(action?.devicePresentationTitle ?? "未分配")
                    .foregroundStyle(
                        selected
                            ? AppTheme.onAccent(for: colorScheme)
                            : (hovered ? AppTheme.accent(for: colorScheme) : calloutForeground)
                    )
                    .lineLimit(1)
                Text(hardwareTitle)
                    .font(AppTypography.calloutDetail)
                    .foregroundStyle(
                        selected
                            ? AppTheme.onAccent(for: colorScheme).opacity(0.82)
                            : (hovered ? AppTheme.accent(for: colorScheme) : calloutForeground)
                    )
                    .lineLimit(1)
            }
            .offset(y: RemoteCanvasMetrics.calloutTextYOffset)
            .padding(.horizontal, 12)
            .padding(.vertical, RemoteCanvasMetrics.calloutVerticalPadding)
            .frame(
                minWidth: 74,
                minHeight: RemoteCanvasMetrics.calloutMinimumHeight,
                alignment: .leading
            )
            .background(
                selected
                    ? AppTheme.accent(for: colorScheme)
                    : (hovered
                        ? hoveredCalloutBackground
                        : (colorScheme == .dark
                            ? AppTheme.surface(for: colorScheme)
                            : AppTheme.canvas(for: colorScheme)))
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
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
                radius: 10,
                x: 6,
                y: 6
            )
            .fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(QuietButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityLabel(hardwareTitle)
        .accessibilityValue(
            "\(store.selectedTrigger.title) · \(action?.devicePresentationTitle ?? "尚未分配动作")"
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var calloutForeground: Color {
        colorScheme == .dark
            ? Color.primary
            : Color(red: 23 / 255, green: 14 / 255, blue: 46 / 255)
    }

    private var hoveredCalloutBackground: Color {
        colorScheme == .dark
            ? Color(red: 20 / 255, green: 43 / 255, blue: 41 / 255)
            : Color(red: 249 / 255, green: 246 / 255, blue: 255 / 255)
    }

}

private struct RemoteHotspot: View {
    let slot: RemoteButtonSlot
    let remoteSize: CGSize

    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isDropTargeted = false

    private var isSelected: Bool { store.selectedSlotID == slot.id }
    private var isPressed: Bool { store.pressedSlotID == slot.id }
    private var assignedAction: RemoteAction? {
        store.action(for: slot.id, trigger: store.selectedTrigger)
    }
    private var isDragging: Bool { store.draggedActionID != nil }
    private var isValidDrop: Bool {
        guard let action = store.draggedAction else { return true }
        return slot.accepts(action)
    }

    var body: some View {
        let width = max(28, remoteSize.width * slot.width)
        let height = max(28, remoteSize.height * slot.height)
        let accent = AppTheme.accent(for: colorScheme)

        Button {
            store.selectSlot(slot)
        } label: {
            ZStack {
                hotspotShape
                    .fill(fillColor(accent: accent))

                hotspotShape
                    .stroke(strokeColor(accent: accent), lineWidth: strokeWidth)

                Circle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.025))
                    .overlay {
                        Circle()
                            .stroke(targetColor(accent: accent), lineWidth: isSelected ? 2 : 1.5)
                    }
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
                    .offset(targetOffset(width: width, height: height))
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: height)
            .contentShape(hotspotShape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.10), value: isHovered)
        .animation(.easeOut(duration: 0.10), value: isPressed)
        .dropDestination(for: String.self) { items, _ in
            guard let actionID = items.first,
                  let action = store.draggedAction,
                  action.id == actionID else {
                store.cancelDragging()
                return false
            }
            guard slot.accepts(action) else {
                store.assign(action, to: slot)
                return false
            }
            store.assign(action, to: slot)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .help("\(slot.name) · \(store.selectedTrigger.title)：\(assignedAction?.title ?? "尚未分配")")
        .accessibilityLabel("\(slot.name)按键")
        .accessibilityValue(
            "\(store.selectedTrigger.title) · \(assignedAction?.devicePresentationTitle ?? "尚未分配动作")"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hotspotShape: HotspotShape {
        HotspotShape(kind: slot.shape)
    }

    private func fillColor(accent: Color) -> Color {
        if isPressed { return accent.opacity(0.16) }
        if isDropTargeted { return (isValidDrop ? accent : Color.red).opacity(0.13) }
        if isSelected { return .clear }
        if isDragging { return (isValidDrop ? accent : Color.red).opacity(0.045) }
        if isHovered { return Color.primary.opacity(0.035) }
        return .clear
    }

    private func strokeColor(accent: Color) -> Color {
        if isDropTargeted { return isValidDrop ? accent : .red }
        if isPressed { return accent.opacity(0.86) }
        if isSelected { return .clear }
        if isDragging { return (isValidDrop ? accent : Color.red).opacity(0.58) }
        if isHovered { return Color.primary.opacity(0.22) }
        return .clear
    }

    private var strokeWidth: CGFloat {
        isSelected || isPressed || isDropTargeted ? 1.8 : 1.4
    }

    private func targetColor(accent: Color) -> Color {
        if isDropTargeted { return isValidDrop ? accent : .red }
        if isSelected || isPressed || isHovered { return accent }
        return .white
    }

    private func targetOffset(width: CGFloat, height: CGFloat) -> CGSize {
        switch slot.shape {
        case .dpadUp:
            CGSize(width: 0, height: -height * 0.29)
        case .dpadLeft:
            CGSize(width: -width * 0.29, height: 0)
        case .dpadRight:
            CGSize(width: width * 0.29, height: 0)
        case .dpadDown:
            CGSize(width: 0, height: height * 0.29)
        case .rockerTop:
            CGSize(width: 0, height: -height * 0.23)
        case .rockerBottom:
            CGSize(width: 0, height: height * 0.23)
        default:
            .zero
        }
    }
}

private struct HotspotShape: Shape {
    let kind: RemoteButtonShape

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .circle:
            Path(ellipseIn: rect)
        case .roundedSquare:
            Path(roundedRect: rect, cornerRadius: min(10, rect.height * 0.35))
        case .capsuleVertical:
            Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.48)
        case .dpadUp:
            dpadSector(in: rect, start: -133, end: -47)
        case .dpadRight:
            dpadSector(in: rect, start: -43, end: 43)
        case .dpadDown:
            dpadSector(in: rect, start: 47, end: 133)
        case .dpadLeft:
            dpadSector(in: rect, start: 137, end: 223)
        case .rockerTop:
            rockerHalf(in: rect, top: true)
        case .rockerBottom:
            rockerHalf(in: rect, top: false)
        }
    }

    private func dpadSector(in rect: CGRect, start: Double, end: Double) -> Path {
        let diameter = min(rect.width, rect.height) - 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = diameter / 2
        let innerRadius = outerRadius * 0.51

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(end),
            endAngle: .degrees(start),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func rockerHalf(in rect: CGRect, top: Bool) -> Path {
        let radius = min(rect.width / 2, rect.height / 2)
        var path = Path()

        if top {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }

        path.closeSubpath()
        return path
    }
}
