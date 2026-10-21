import SwiftUI

/// The surfaces every pane is built from: the page behind the cards, the card
/// itself, the hairline around it, and the well a control sits in.
///
/// Each one is declared for both appearances rather than derived from a single
/// semantic colour. The earlier version used `.textBackgroundColor` for the
/// page, which resolves to pure white in light mode — the same value the card
/// resolved to, leaving every borderless card invisible. Declaring both halves
/// keeps a real step between page and card whichever way the desktop is set.
extension Color {
    /// The page the cards sit on.
    static let paneBackground = surface(dark: 0x1C_1C_1E, light: 0xF2_F2_F4)

    /// A raised surface holding rows or a preview. Lighter than the page in
    /// dark mode and darker than it in light, so a card reads as raised in
    /// both rather than flipping meaning between appearances.
    static let cardSurface = surface(dark: 0x2A_2A_2C, light: 0xFF_FF_FF)

    /// Hairline between rows inside a card, and around its edge. Kept at a
    /// contrast the eye can actually find: the previous 4.5% sat at 1.14:1.
    static let cardBorder = separator(0.12)

    /// Fill behind a recessed control — a search field, a number field, an
    /// unselected segment.
    static let controlWell = separator(0.10)

    /// Fill drawn under the pointer. Weak enough to read as a highlight, strong
    /// enough to be visible on a dim display.
    static let hoverFill = separator(0.08)

    /// Small supporting text — counts, categories, timestamps. `.tertiary`
    /// lands at 1.88:1 in light mode, which fails every contrast threshold, so
    /// metadata uses this instead and reserves `.tertiary` for decoration.
    static let metaText = separator(0.60)

    private static func surface(dark: Int, light: Int) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let value =
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? dark : light
                return NSColor(
                    srgbRed: Double((value >> 16) & 0xFF) / 255,
                    green: Double((value >> 8) & 0xFF) / 255,
                    blue: Double(value & 0xFF) / 255,
                    alpha: 1)
            })
    }

    /// White in dark mode, black in light, at the opacity given.
    private static func separator(_ opacity: Double) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(white: 1, alpha: opacity) : NSColor(white: 0, alpha: opacity)
            })
    }
}

/// Shared geometry on a 4 pt grid.
///
/// Before this existed in usable form the app carried 12 corner radii, 19
/// padding values and 22 stack spacings. Panes size themselves from these so a
/// card in Borders lines up with a card in Layout.
enum Metrics {
    static let xs: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    /// Gap between the cards stacked down a page.
    static let cardGap: CGFloat = 16
    /// Gap between items in a grid of cards.
    static let gridGap: CGFloat = 16
    /// Margin from the page edge to its content.
    static let pageMargin: CGFloat = 24

    /// A chip, a segment, a small control.
    static let radiusSmall: CGFloat = 6
    /// A button-sized control or a navigation row.
    static let radiusControl: CGFloat = 8
    /// Any card, including previews and grid tiles.
    static let radiusCard: CGFloat = 12
}

/// Geometry for `SettingsCard` and its rows.
enum CardMetrics {
    static let cornerRadius = Metrics.radiusCard
    static let horizontalPadding = Metrics.large
    static let rowVerticalPadding = Metrics.medium

    /// Dividers start at the row's text, not the card's edge, so the eye reads
    /// one column of titles rather than a ladder of full-width rules.
    static let dividerInset = horizontalPadding
}
