import AppKit
import Macarchy
import SwiftUI

struct ComponentCanvas: View {
    let bar: MenuBarModel
    let component: BarComponent
    let sample: String
    let guides: Bool
    let wallpaper: URL?
    @Binding var selectedParts: Set<String>
    var onResize: ((Double, Bool) -> Void)?
    var onMove: ((Set<String>, CGSize) -> Void)?
    var onSize: ((String, Double, Bool) -> Void)?
    @State private var start: Double?
    @State private var dragScale: Double?
    @State private var resizeWidth: Double?
    @State private var boxCentre: Double = 0
    @State private var pendingWidth: Double?
    @State private var resizingBox = false
    @State private var lastTranslation = CGSize.zero

    private var layout: MenuBarLayout { MenuBarLayout(bar: bar) }
    private var items: [SketchybarItem] {
        bar.items.filter {
            component.members.contains($0.id) && $0.isOnScreen && !$0.id.hasPrefix("gap.")
        }
    }
    private var width: Double {
        max(
            component.kind == "spacer" ? 1 : 24,
            component.boxWidth ?? layout.frames[component.id]?.width
                ?? MenuBarLayout.customWidth(component))
    }
    private var geometry: ComponentGeometry {
        let origin = layout.frames[component.id]?.minX ?? items.map(\.frame.minX).min() ?? 0
        let offsets = Dictionary(
            uniqueKeysWithValues: items.map {
                ($0.id, Double((layout.memberFrames[$0.id]?.minX ?? $0.frame.minX) - origin))
            })
        return ComponentGeometry(
            items: items, component: component, sample: sample, offsets: offsets)
    }

    var body: some View {
        VStack(spacing: Metrics.small) {
            HStack {
                Text("COMPONENT BOX").eyebrowStyle()
                HelpTooltip(
                    text: component.kind == "spacer"
                        ? "Empty space between components." : "Content outside the box is hidden.")
                Spacer()
                Text("\(Int(width)) × \(Int(bar.height)) pt").font(.badge).foregroundStyle(
                    .secondary)
            }
            ZStack {
                WallpaperThumbnail(url: wallpaper, height: 118, crop: .top)
                Color(macarchyHex: bar.colour) ?? .clear
                GeometryReader { proxy in
                    let fittedScale = ComponentPreviewFit.scale(
                        content: CGSize(
                            width: width + 36 + abs(boxCentre) * 2, height: bar.height + 16),
                        available: proxy.size)
                    let scale = resizingBox ? (dragScale ?? fittedScale) : fittedScale
                    Color.clear.overlay {
                        box
                            .overlay(alignment: .leading) {
                                edgeHandle(leading: true, scale: scale)
                            }
                            .overlay(alignment: .trailing) {
                                edgeHandle(leading: false, scale: scale)
                            }
                            .scaleEffect(scale)
                            .offset(x: boxCentre * scale)
                    }
                }
            }.frame(height: 118).clipShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall))
            HStack {
                if !geometry.contentBounds.isNull,
                    geometry.contentBounds.minX < 0 || geometry.contentBounds.maxX > width
                        || geometry.contentBounds.minY < 0
                        || geometry.contentBounds.maxY > bar.height
                {
                    Label("Some content is clipped", systemImage: "crop").foregroundStyle(.orange)
                }
            }.font(.meta).foregroundStyle(.secondary)
        }
        .onChange(of: width) { _, newWidth in
            if pendingWidth != newWidth { boxCentre = 0 }
            pendingWidth = nil
        }
    }

    private var box: some View {
        ZStack(alignment: .topLeading) {
            if component.isCustom {
                ComponentChip(component: component, value: component.text)
            } else {
                ForEach(geometry.items) { item in
                    MenuBarItemView(
                        item: item, iconOverride: component.iconColour ?? component.colour,
                        labelOverride: component.colour
                    )
                    .offset(x: geometry.offsets[item.id] ?? 0)
                }
                ForEach(geometry.parts) { part in
                    partTarget(part)
                }
            }
        }
        .frame(width: width, height: bar.height, alignment: .topLeading)
        .background(Color(macarchyHex: component.backgroundColour) ?? .clear)
        .clipped()
        .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 1))
    }

    private func partTarget(_ part: ComponentGeometry.Part) -> some View {
        GeometryReader { proxy in
            let scale = max(proxy.frame(in: .global).width / max(width, 1), 0.01)
            Rectangle().fill(Color.clear)
                .overlay(
                    Rectangle().strokeBorder(
                        selectedParts.contains(part.id) ? Color.accentColor : .clear, lineWidth: 0.7
                    )
                )
                .frame(width: max(part.frame.width, 4), height: max(part.frame.height, 4))
                .contentShape(Rectangle())
                .onTapGesture { select(part.id, extending: NSEvent.modifierFlags.contains(.shift)) }
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .global)
                        .onChanged { value in
                            if !selectedParts.contains(part.id) {
                                select(part.id, extending: NSEvent.modifierFlags.contains(.shift))
                            }
                            if dragScale == nil { dragScale = scale; bar.beginInteraction() }
                            let factor = max(dragScale ?? scale, 0.01)
                            let delta = ComponentPreviewFit.dragStep(
                                translation: value.translation,
                                consumed: lastTranslation, scale: factor)
                            if delta != .zero { onMove?(selectedParts, delta) }
                            lastTranslation.width += delta.width * factor
                            lastTranslation.height += delta.height * factor
                        }.onEnded { _ in finishDrag() }
                )
                .overlay(alignment: .leading) {
                    if selectedParts == [part.id] { partEdge(part, leading: true, scale: scale) }
                }
                .overlay(alignment: .trailing) {
                    if selectedParts == [part.id] { partEdge(part, leading: false, scale: scale) }
                }
                .offset(x: part.frame.minX, y: part.frame.minY)
        }
    }

    private func partEdge(_ part: ComponentGeometry.Part, leading: Bool, scale: Double) -> some View
    {
        Capsule().fill(Color.accentColor).frame(width: 3, height: min(12, part.frame.height))
            .padding(.horizontal, 3).contentShape(Rectangle())
            .offset(x: leading ? -4.5 : 4.5)
            .help(
                leading
                    ? "Drag the left edge to resize this part"
                    : "Drag the right edge to resize this part"
            )
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if start == nil {
                            start = part.frame.height
                            resizeWidth = part.frame.width
                            dragScale = scale
                            bar.beginInteraction()
                        }
                        let delta =
                            value.translation.width / max(dragScale ?? scale, 0.01)
                            * (leading ? -1 : 1)
                        let targetWidth = max(4, (resizeWidth ?? part.frame.width) + delta)
                        let height =
                            (start ?? part.frame.height) * targetWidth
                            / max(resizeWidth ?? part.frame.width, 1)
                        onSize?(part.id, height, leading)
                    }.onEnded { _ in finishDrag() }
            )
            .accessibilityLabel(leading ? "Resize left part edge" : "Resize right part edge")
    }

    private func select(_ id: String, extending: Bool) {
        if extending {
            if selectedParts.contains(id) {
                selectedParts.remove(id)
            } else {
                selectedParts.insert(id)
            }
        } else {
            selectedParts = [id]
        }
    }

    private func edgeHandle(leading: Bool, scale: Double) -> some View {
        Capsule().fill(Color.accentColor).frame(width: 4, height: 18)
            .padding(.horizontal, 5).contentShape(Rectangle())
            .offset(x: leading ? -17 : 17)
            .help("Drag to resize the component box")
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if start == nil {
                            start = width
                            dragScale = scale
                            resizingBox = true
                            bar.beginInteraction()
                        }
                        let delta =
                            value.translation.width / max(dragScale ?? scale, 0.01)
                            * (leading ? -1 : 1)
                        resizeBox(to: (start ?? width) + delta, leading: leading)
                    }.onEnded { _ in finishDrag() }
            )
            .accessibilityLabel(leading ? "Resize left box edge" : "Resize right box edge")
            .accessibilityAdjustableAction {
                resizeBox(to: width + ($0 == .increment ? 4 : -4), leading: leading)
            }
    }

    private func resizeBox(to proposedWidth: Double, leading: Bool) {
        let newWidth = min(max(proposedWidth.rounded(), component.kind == "spacer" ? 1 : 24), 1000)
        guard newWidth != width else { return }
        boxCentre += (newWidth - width) / 2 * (leading ? -1 : 1)
        pendingWidth = newWidth
        onResize?(newWidth, leading)
    }

    private func finishDrag() {
        resizingBox = false
        start = nil
        resizeWidth = nil
        dragScale = nil
        lastTranslation = .zero
        bar.endInteraction()
    }
}
