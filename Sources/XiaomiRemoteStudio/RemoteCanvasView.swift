import SwiftUI
import UniformTypeIdentifiers

struct RemoteCanvasView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let visibleFraction = 0.655
            let viewportTop = min(max(proxy.size.height * 0.12, 72), 96)
            let viewportHeight = min(max(proxy.size.height - viewportTop - 14, 420), 620)
            let imageHeight = viewportHeight / visibleFraction
            let imageWidth = imageHeight * (500.0 / 1843.0)
            let viewportCenterY = viewportTop + viewportHeight / 2

            ZStack {
                RemoteProductImage()
                    .frame(width: imageWidth, height: imageHeight)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 16, y: 10)
                    .frame(width: imageWidth, height: viewportHeight, alignment: .top)
                    .clipped()
                    .position(x: proxy.size.width / 2, y: viewportCenterY)

                ForEach(RemoteButtonSlot.demoSlots) { slot in
                    RemoteHotspot(slot: slot, remoteSize: CGSize(width: imageWidth, height: imageHeight))
                        .position(
                            x: proxy.size.width / 2 + (slot.x - 0.5) * imageWidth,
                            y: viewportTop + slot.y * imageHeight
                        )
                }

                VStack {
                    HStack {
                        Text("选择遥控器上的按键")
                            .font(AppTypography.supportingMedium)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    private var assignedAction: RemoteAction? { store.action(for: slot.id) }
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
            store.selectedSlotID = slot.id
        } label: {
            ZStack {
                hotspotShape
                    .fill(fillColor(accent: accent))

                hotspotShape
                    .stroke(strokeColor(accent: accent), lineWidth: strokeWidth)

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
                  let action = RemoteAction.catalog.first(where: { $0.id == actionID }) else {
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
        .help("\(slot.name)：\(assignedAction?.title ?? "尚未分配")")
        .accessibilityLabel("\(slot.name)按键")
        .accessibilityValue(assignedAction?.title ?? "尚未分配动作")
    }

    private var hotspotShape: HotspotShape {
        HotspotShape(kind: slot.shape)
    }

    private func fillColor(accent: Color) -> Color {
        if isPressed { return accent.opacity(0.16) }
        if isDropTargeted { return (isValidDrop ? accent : Color.red).opacity(0.13) }
        if isSelected { return accent.opacity(colorScheme == .dark ? 0.14 : 0.07) }
        if isDragging { return (isValidDrop ? accent : Color.red).opacity(0.045) }
        if isHovered { return Color.primary.opacity(0.035) }
        return .clear
    }

    private func strokeColor(accent: Color) -> Color {
        if isDropTargeted { return isValidDrop ? accent : .red }
        if isSelected || isPressed { return accent.opacity(0.86) }
        if isDragging { return (isValidDrop ? accent : Color.red).opacity(0.58) }
        if isHovered { return Color.primary.opacity(0.26) }
        return .clear
    }

    private var strokeWidth: CGFloat {
        isSelected || isPressed || isDropTargeted ? 1.5 : 1
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
