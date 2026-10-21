import SwiftUI

/// A theme's wallpaper, filling whatever space it is given.
///
/// This used to compose a synthetic desktop — bar, tiled panes, character art,
/// meters — at every card size. It was slow, it was noisy at small sizes, and
/// the panes were translucent enough that stacked cards bled through each
/// other. The wallpaper is the thing people actually recognise a theme by, so
/// that is what gets shown.
struct DesktopArtwork: View {
    enum Variant {
        case desktop
        case menuBar
        case windows
        case compact
    }

    var accent: Color
    var wallpaper: URL?
    var palette: GhosttyPalette?
    var variant: Variant = .desktop
    var height: CGFloat = 190

    init(
        accent: Color, wallpaper: URL? = nil, palette: GhosttyPalette? = nil,
        menuOnly: Bool, height: CGFloat = 190
    ) {
        self.init(
            accent: accent, wallpaper: wallpaper, palette: palette,
            variant: menuOnly ? .menuBar : .desktop, height: height)
    }

    init(
        accent: Color, wallpaper: URL? = nil, palette: GhosttyPalette? = nil,
        variant: Variant = .desktop, height: CGFloat = 190
    ) {
        self.accent = accent
        self.wallpaper = wallpaper
        self.palette = palette
        self.variant = variant
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Opaque, so a cover in the carousel never shows the one
                // behind it through its own background.
                Rectangle().fill(fallback)
                WallpaperThumbnail(url: wallpaper, height: height)
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
            }
            .frame(width: geometry.size.width, height: height)
            .clipped()
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wallpaper preview")
    }

    /// Shown while the image decodes, and for themes that ship no wallpaper.
    private var fallback: LinearGradient {
        LinearGradient(
            colors: [
                palette?.background ?? Color(white: 0.08),
                accent.opacity(0.35)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
