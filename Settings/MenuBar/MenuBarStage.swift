import AppKit
import CoreText
import SwiftUI
import Desktop

/// Scales a native-size paint of the live bar. The empty desktop middle is
/// collapsed so items can be larger than a full-width 1512pt shrink.
struct MenuBarStage: View {
    @Bindable var bar: MenuBarModel
    let palette: GhosttyPalette?
    let wallpaper: URL?

    @State private var editing: SketchybarItem?
    @State private var dragging: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dropTarget: String?
    @State private var stageHeight: CGFloat = 44

    var body: some View {
        // GeometryReader inside a Form row reports a useless width unless the
        // row already has a size. Background-on-Color.clear is the Form-safe way.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: stageHeight)
            .background { GeometryReader { proxy in canvas(width: proxy.size.width) } }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .onAppear { Self.registerAppFont() }
            .onPreferenceChange(StageHeightKey.self) { stageHeight = $0 }
            .animation(.easeInOut(duration: 0.15), value: bar.height)
            .popover(item: $editing) { item in
                MenuBarItemEditor(item: item, bar: bar)
            }
    }

    private func canvas(width: CGFloat) -> some View {
        let layout = PackedBar.fit(
            items: leaves, barHeight: max(bar.height, 35), previewWidth: width)

        return ZStack(alignment: .topLeading) {
            WallpaperThumbnail(url: wallpaper, height: layout.stageHeight)
                .frame(width: width, height: layout.stageHeight)
                .clipped()
            (Color(macarchyHex: bar.color) ?? .clear)
                .frame(width: width, height: layout.barHeight)
            Notch(frame: layout.notch)
            ForEach(leaves) { item in
                if let frame = layout.frames[item.id] {
                    placed(item, frame: frame, scale: layout.scale, frames: layout.frames)
                }
            }
            if let dragging, let item = bar.items.first(where: { $0.id == dragging }) {
                MenuBarItemView(item: item)
                    .scaleEffect(layout.scale)
                    .position(dragLocation)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: layout.stageHeight)
        .clipped()
        .coordinateSpace(name: "preview")
        .onHover { inside in
            if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .preference(key: StageHeightKey.self, value: layout.stageHeight)
    }

    private var leaves: [SketchybarItem] {
        bar.items.filter(\.isOnScreen).filter(\.isLeaf)
    }

    private func placed(
        _ item: SketchybarItem, frame: CGRect, scale: CGFloat, frames: [String: CGRect]
    ) -> some View {
        MenuBarItemView(item: item, dimmed: dragging == item.id)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .background(alignment: .leading) {
                if dropTarget == item.id {
                    Capsule().fill(Color.accentColor).frame(width: 2).offset(x: -2)
                }
            }
            .position(x: frame.midX, y: frame.midY)
            .contentShape(Rectangle())
            .gesture(drag(item, frames: frames))
    }

    private func drag(_ item: SketchybarItem, frames: [String: CGRect]) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("preview"))
            .onChanged { value in
                if dragging == nil { NSCursor.closedHand.push() }
                dragging = item.id
                dragLocation = value.location
                dropTarget = target(at: value.location, excluding: item.id, frames: frames)
            }
            .onEnded { value in
                NSCursor.pop()
                let travelled = hypot(value.translation.width, value.translation.height)
                if travelled < 5 {
                    editing = item
                } else if let dropTarget {
                    bar.move(item.id, onto: dropTarget)
                }
                dragging = nil
                dropTarget = nil
            }
    }

    private func target(
        at point: CGPoint, excluding: String, frames: [String: CGRect]
    ) -> String? {
        leaves.first { item in
            guard item.id != excluding, let frame = frames[item.id] else { return false }
            return frame.insetBy(dx: -4, dy: -4).contains(point)
        }?.id
    }

    /// The app font lives in ~/Library/Fonts but SwiftUI only sees it after
    /// an explicit process-level register — otherwise `:firefox:` is literal.
    private static func registerAppFont() {
        let url = Paths.home.appending(path: "Library/Fonts/sketchybar-app-font.ttf") as CFURL
        CTFontManagerRegisterFontsForURL(url, .process, nil)
    }
}

private struct StageHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 44
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Maps live `bounding_rects` into the preview by dropping the unused middle.
@MainActor
private struct PackedBar {
    let scale: CGFloat
    let frames: [String: CGRect]
    let notch: CGRect
    let barHeight: CGFloat
    let stageHeight: CGFloat

    static func fit(
        items: [SketchybarItem], barHeight: CGFloat, previewWidth: CGFloat
    ) -> PackedBar {
        let screen = max(NSScreen.main?.frame.width ?? 1512, 1)
        let notchNative = Notch.current.frame
        let mid = screen / 2
        let leftMax = items.filter { $0.frame.midX < mid }.map(\.frame.maxX).max() ?? 0
        let rightMin = items.filter { $0.frame.midX >= mid }.map(\.frame.minX).min() ?? screen
        let leftNative = max(leftMax, 0)
        let rightNative = max(screen - rightMin, 0)
        let gutter: CGFloat = 12
        let packed = leftNative + gutter + notchNative.width + gutter + rightNative
        let scale = max((previewWidth - 8) / max(packed, 1), 0.01)
        let pad: CGFloat = 5
        let scaledBar = barHeight * scale

        var frames: [String: CGRect] = [:]
        for item in items where item.frame.midX < mid {
            frames[item.id] = CGRect(
                x: 4 + item.frame.minX * scale,
                y: pad + item.frame.minY * scale,
                width: item.frame.width * scale,
                height: item.frame.height * scale)
        }
        let rightOrigin = previewWidth - 4 - rightNative * scale
        for item in items where item.frame.midX >= mid {
            frames[item.id] = CGRect(
                x: rightOrigin + (item.frame.minX - rightMin) * scale,
                y: pad + item.frame.minY * scale,
                width: item.frame.width * scale,
                height: item.frame.height * scale)
        }

        let leftEnd = 4 + leftNative * scale
        let rightStart = previewWidth - 4 - rightNative * scale
        let notchWidth = notchNative.width * scale
        let notchX = (leftEnd + rightStart) / 2 - notchWidth / 2
        let notch = CGRect(
            x: notchX, y: pad, width: notchWidth, height: notchNative.height * scale)

        return PackedBar(
            scale: scale, frames: frames, notch: notch,
            barHeight: scaledBar, stageHeight: scaledBar + pad * 2)
    }
}

/// Live notch, from the same `NSScreen` auxiliary areas the bar already avoids.
private struct Notch: View {
    let frame: CGRect

    static var current: Notch {
        let screen = NSScreen.main
        let left = screen?.auxiliaryTopLeftArea ?? .zero
        let right = screen?.auxiliaryTopRightArea ?? .zero
        let x = left.maxX
        let width = max(0, right.minX - left.maxX)
        let height = max(left.height, right.height)
        return Notch(frame: CGRect(x: x, y: 0, width: width, height: height))
    }

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: frame.height / 2.4,
            bottomTrailingRadius: frame.height / 2.4,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(Color.black)
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .allowsHitTesting(false)
    }
}
