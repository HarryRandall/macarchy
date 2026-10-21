import SwiftUI

import Macarchy

/// Manual mode compares the last applied appearance with the unsaved draft.
struct BorderPreview: View {
    let appearance: BorderAppearance
    let before: BorderAppearance?
    let wallpaper: URL?

    /// The preview window stands in for a real one roughly 720pt wide, so
    /// widths and radii are drawn at that ratio rather than 1:1. Drawing them
    /// full size made an 11pt border read like a picture frame.
    private static let windowSize = CGSize(width: 232, height: 146)
    private static let representedWidth: Double = 720
    private var scale: Double { Self.windowSize.width / Self.representedWidth }

    var body: some View {
        ZStack {
            WallpaperThumbnail(url: wallpaper, height: 232)
                .overlay(.black.opacity(0.38))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 32) { windows }
                VStack(spacing: 20) { windows }
            }
            .padding(18)
        }
        .frame(minHeight: 232)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        // Clipping crops pixels, not the scaled wallpaper's hit area. The
        // decorative preview must never intercept clicks on nearby controls.
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var windows: some View {
        if let before { pane(before, caption: "Before") }
        pane(appearance, caption: before == nil ? nil : "After")
    }

    /// Same threshold the model uses, so the preview can't disagree with what
    /// actually gets sent to the daemon.
    private func isSquare(_ radius: Double) -> Bool { radius < BordersModel.squareThreshold }

    /// A zero-radius RoundedRectangle still antialiases its corners; an actual
    /// Rectangle is the only way to get a genuinely hard 90-degree corner.
    private func shape(radius: Double) -> AnyShape {
        radius <= 0.01
            ? AnyShape(Rectangle())
            : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func pane(_ appearance: BorderAppearance, caption: String?) -> some View {
        let radius = appearance.previewRadius
        let scaledWidth = appearance.width * scale
        let windowRadius = isSquare(radius) ? 0 : radius * scale
        let borderRadius = isSquare(radius) ? 0 : windowRadius + scaledWidth / 2
        let gutter = max(scaledWidth, 1)

        return VStack(spacing: 10) {
            ZStack {
                shape(radius: windowRadius)
                    .fill(.regularMaterial)
                    .overlay(
                        VStack(spacing: 0) {
                            HStack(spacing: 4) {
                                ForEach([Color.red, .yellow, .green], id: \.self) { dot in
                                    Circle().fill(dot.opacity(0.85)).frame(width: 7, height: 7)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            Divider().opacity(0.4)
                            Text("~  $ _")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                            Spacer()
                        }
                    )
                    .clipShape(shape(radius: windowRadius))

                if appearance.visible && scaledWidth > 0 {
                    // AnyShape isn't insettable, so this strokes centred on a
                    // path grown by half the width — putting the stroke's inner
                    // edge exactly on the window boundary, where the real one sits.
                    shape(radius: borderRadius)
                        .stroke(
                            Color(macarchyHex: appearance.activeColour) ?? .accentColor,
                            lineWidth: scaledWidth
                        )
                        .padding(-scaledWidth / 2)
                }
            }
            .frame(width: Self.windowSize.width, height: Self.windowSize.height)
            .padding(gutter)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(caption ?? "Border preview"), \(isSquare(radius) ? "square" : "rounded") corners")
    }
}
