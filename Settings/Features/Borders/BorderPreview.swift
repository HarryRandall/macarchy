import SwiftUI

/// The border as it will actually render, over the current wallpaper.
///
/// Normally one window. A second appears only when the corner radius has been
/// changed but existing windows predate it — the one setting on this pane whose
/// effect is genuinely deferred, and so the only one worth showing twice.
struct BorderPreview: View {
    let width: Double
    let cornerRadius: Double
    /// Radius the already-open windows were created with, captured at launch.
    let appliedCornerRadius: Double?
    let activeColor: Color
    let wallpaper: URL?
    let visible: Bool

    /// The preview window stands in for a real one roughly 720pt wide, so
    /// widths and radii are drawn at that ratio rather than 1:1. Drawing them
    /// full size made an 11pt border read like a picture frame.
    private static let windowSize = CGSize(width: 232, height: 146)
    private static let representedWidth: Double = 720
    private var scale: Double { Self.windowSize.width / Self.representedWidth }

    private var scaledWidth: Double { width * scale }

    private var isPending: Bool {
        guard let applied = appliedCornerRadius else { return false }
        return abs(applied - cornerRadius) > 0.01
    }

    var body: some View {
        ZStack {
            WallpaperThumbnail(url: wallpaper, height: 208)
                .overlay(.black.opacity(0.38))

            HStack(spacing: 40) {
                if isPending, let applied = appliedCornerRadius {
                    pane(radius: applied, caption: "Open windows", dimmed: true)
                    pane(radius: cornerRadius, caption: "New windows", dimmed: false)
                } else {
                    pane(radius: cornerRadius, caption: nil, dimmed: false)
                }
            }
        }
        .frame(height: 208)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .animation(.easeInOut(duration: 0.18), value: isPending)
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

    private func pane(radius: Double, caption: String?, dimmed: Bool) -> some View {
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
                            Spacer()
                        }
                    )
                    .clipShape(shape(radius: windowRadius))

                if visible && scaledWidth > 0 {
                    // AnyShape isn't insettable, so this strokes centred on a
                    // path grown by half the width — putting the stroke's inner
                    // edge exactly on the window boundary, where the real one sits.
                    shape(radius: borderRadius)
                        .stroke(activeColor, lineWidth: scaledWidth)
                        .padding(-scaledWidth / 2)
                }
            }
            .frame(width: Self.windowSize.width, height: Self.windowSize.height)
            .padding(gutter)
            .opacity(dimmed ? 0.5 : 1)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(dimmed ? 0.55 : 0.85))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(caption ?? "Border preview"), \(isSquare(radius) ? "square" : "rounded") corners")
    }
}
