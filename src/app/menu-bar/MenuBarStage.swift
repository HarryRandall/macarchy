import AppKit
import CoreText
import SwiftUI
import UniformTypeIdentifiers
import Macarchy

struct MenuBarStage: View {
    @Bindable var bar: MenuBarModel
    let wallpaper: URL?
    var half: String?
    @State private var dragging: String?
    @State private var target: String?

    var body: some View {
        GeometryReader { proxy in
            let layout = MenuBarLayout(bar: bar)
            let nativeWidth = half == nil ? layout.screenWidth : layout.screenWidth / 2
            let width = half == nil ? proxy.size.width : max(proxy.size.width, nativeWidth)
            let scale = width / nativeWidth
            ScrollView(.horizontal) {
                canvas(layout: layout, width: width, scale: scale)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: half == nil ? 82 : max(104, bar.height + 48))
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
        let offset = half == "right" ? layout.screenWidth / 2 : 0
        let stageHeight = half == nil ? 78.0 : max(96, bar.height + 40)
        return ZStack(alignment: .topLeading) {
            WallpaperThumbnail(url: wallpaper, height: stageHeight)
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
                HStack(spacing: 8) {
                    Text(component.icon).font(.system(size: 15))
                    Text(component.text).font(.system(size: 12))
                }
                .foregroundStyle(Color(macarchyHex: component.colour) ?? .white)
                .padding(.leading, bar.draft.padding(for: component))
                .frame(width: frame.width, height: frame.height, alignment: .leading)
                .opacity(component.kind == "spacer" ? 0 : 1)
            } else {
                ForEach(componentItems(component)) { item in
                    if let memberFrame = layout.memberFrames[item.id] {
                        MenuBarItemView(item: item)
                            .offset(x: memberFrame.minX - frame.minX, y: memberFrame.minY)
                    }
                }
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    bar.selection.contains(component.id) ? Color.accentColor.opacity(0.12) : .clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4).strokeBorder(
                        bar.selection.contains(component.id) || dragging == component.id
                            ? Color.accentColor : .clear, lineWidth: 2)
                )
                .padding(.trailing, bar.draft.spacing(for: component))
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
        .overlay(alignment: .leading) {
            if target == component.id { Rectangle().fill(Color.accentColor).frame(width: 2) }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: frame.width * scale, height: frame.height * scale, alignment: .topLeading)
        .offset(x: (frame.minX - offset) * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(component.title)
        .help("\(component.title): click to edit, drag to move")
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
