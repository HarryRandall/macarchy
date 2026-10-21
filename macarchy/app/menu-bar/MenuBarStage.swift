import AppKit
import CoreText
import SwiftUI
import UniformTypeIdentifiers
import Macarchy

struct MenuBarStage: View {
    @Bindable var bar: MenuBarModel
    let wallpaper: URL?
    var half: String?
    var compact = false
    @State private var dragging: String?
    @State private var target: String?

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuBarLayout(bar: bar)
            let nativeWidth = half == nil ? layout.screenWidth : layout.screenWidth / 2
            let width =
                compact || half == nil ? proxy.size.width : max(proxy.size.width, nativeWidth)
            let scale = width / nativeWidth
            ScrollView(.horizontal) {
                canvas(layout: layout, width: width, scale: scale)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: compact ? 48 : half == nil ? 82 : max(104, bar.height + 48))
        .onAppear {
            let font = Paths.home.appending(path: "Library/Fonts/sketchybar-app-font.ttf") as CFURL
            CTFontManagerRegisterFontsForURL(font, .process, nil)
        }
    }

    private var visibleComponents: [BarComponent] {
        bar.draft.components.filter { $0.visible && (half == nil || $0.side == half) }
    }

    private func componentItems(_ component: BarComponent) -> [SketchybarItem] {
        bar.items.filter {
            component.members.contains($0.id) && $0.drawing && !$0.id.hasPrefix("gap.")
        }
    }

    private func canvas(layout: MenuBarLayout, width: CGFloat, scale: CGFloat) -> some View {
        let offset =
            half == "right" ? layout.screenWidth / 2 : half == "center" ? layout.screenWidth / 4 : 0
        let stageHeight = half == nil ? 78.0 : max(96, bar.height + 40)
        return ZStack(alignment: .topLeading) {
            WallpaperThumbnail(
                url: wallpaper, height: stageHeight,
                crop: bar.draft.geometry["position"] == "bottom" ? .bottom : .top
            )
            .frame(width: layout.screenWidth * scale)
            .offset(x: -offset * scale).allowsHitTesting(false)
            (Color(macarchyHex: bar.colour) ?? .clear)
                .frame(width: width, height: bar.height * scale).allowsHitTesting(false)
            ForEach(visibleComponents) { component in
                if let frame = layout.frames[component.id] {
                    group(component, frame: frame, layout: layout, scale: scale, offset: offset)
                }
            }
            if layout.notch.width > 0 && bar.draft.geometry["position"] != "bottom" {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 9 * scale,
                    bottomTrailingRadius: 9 * scale, topTrailingRadius: 0
                )
                .fill(.black)
                .frame(width: layout.notch.width * scale, height: layout.notch.height * scale)
                .offset(x: (layout.notch.minX - offset) * scale)
                .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: stageHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func group(
        _ component: BarComponent, frame: CGRect, layout: MenuBarLayout,
        scale: CGFloat, offset: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if component.isCustom {
                ComponentChip(component: component, value: component.text)
                    .padding(.leading, bar.draft.padding(for: component))
                    .frame(width: frame.width, height: frame.height, alignment: .leading)
                    .opacity(component.kind == "spacer" ? 0 : 1)
            } else {
                ForEach(componentItems(component)) { item in
                    if let memberFrame = layout.memberFrames[item.id] {
                        MenuBarItemView(
                            item: item.presenting(component),
                            iconOverride: component.iconColour ?? component.colour,
                            labelOverride: component.colour
                        )
                        .offset(x: memberFrame.minX - frame.minX, y: memberFrame.minY)
                    }
                }
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .background {
            if let fill = Color(macarchyHex: component.backgroundColour) {
                RoundedRectangle(cornerRadius: component.cornerRadius, style: .continuous)
                    .fill(fill)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .overlay { hitArea(component) }
        .overlay(alignment: .leading) {
            if target == component.id { Rectangle().fill(Color.accentColor).frame(width: 2) }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: frame.width * scale, height: frame.height * scale, alignment: .topLeading)
        .offset(x: (frame.minX - offset) * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(component.title)
        .accessibilityAddTraits(
            bar.selection.contains(component.id) ? [.isButton, .isSelected] : .isButton
        )
        .accessibilityAction(named: "Edit") {
            bar.select(component.id)
            bar.side = component.side
        }
        .hoverHelp("Click to select, drag to reorder")
    }

    /// The selection ring, and the click and drag targets over a group.
    ///
    /// Kept out of `group` so that function stays within its length budget,
    /// and so the drag handling reads in one piece.
    private func hitArea(_ component: BarComponent) -> some View {
        let isSelected = bar.selection.contains(component.id)
        return RoundedRectangle(cornerRadius: Metrics.xs)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.xs).strokeBorder(
                    isSelected || dragging == component.id ? Color.accentColor : .clear,
                    lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                bar.select(component.id, extending: NSEvent.modifierFlags.contains(.shift))
                bar.side = component.side
            }
            .onDrag {
                if !bar.selection.contains(component.id) { bar.select(component.id) }
                dragging = component.id
                return NSItemProvider(object: component.id as NSString)
            }
            .onDrop(
                of: [UTType.text],
                isTargeted: Binding(
                    get: { target == component.id }, set: { target = $0 ? component.id : nil }
                )
            ) { providers in
                acceptDrop(providers, target: component.id)
            }
    }

    private func acceptDrop(_ providers: [NSItemProvider], target: String) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: String.self) { value, _ in
            guard let value else { return }
            Task { @MainActor in
                guard bar.draft.components.contains(where: { $0.id == value }) else { return }
                bar.move(value, before: target)
                dragging = nil
                self.target = nil
            }
        }
        return true
    }
}
