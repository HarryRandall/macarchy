import SwiftUI

/// The three surfaces every pane is built from: the page behind the cards, the
/// card itself, and the hairline between rows.
///
/// These are deliberately derived from the system's semantic colours rather
/// than hardcoded greys — the app follows the desktop's appearance, and a theme
/// switch can put it in light mode without warning.
extension Color {
    /// The page the cards sit on.
    static let paneBackground = Color(nsColor: .textBackgroundColor)

    /// A subtly raised surface that follows the system appearance.
    static let cardSurface = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.155, alpha: 1) : NSColor(white: 1, alpha: 1)
        })

    /// Hairline between rows inside a card, and around its edge.
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.45)

    /// Fill behind an unselected segment, search field, or number field.
    static let controlWell = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
}

/// Shared geometry. Rows are sized from these rather than from per-pane
/// literals, so a card in Borders lines up with a card in Layout.
enum CardMetrics {
    static let cornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12

    /// Dividers start at the row's text, not the card's edge, so the eye reads
    /// one column of titles rather than a ladder of full-width rules.
    static let dividerInset: CGFloat = horizontalPadding
}
