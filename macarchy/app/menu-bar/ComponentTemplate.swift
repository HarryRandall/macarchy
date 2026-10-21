import Macarchy
import SwiftUI

/// A component you can start from rather than building up from a blank chip.
///
/// Each one carries the glyph, the way its reading is written out, and the
/// values the studio should render it at — a battery is worth seeing at 4% and
/// 100%, a track name at its longest.
struct ComponentTemplate: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let icon: String
    let format: String?
    let samples: [String]
    let tint: Color
    let blurb: String

    static let all: [ComponentTemplate] = [
        .init(
            id: "text", title: "Text", symbol: "textformat", icon: "",
            format: nil,
            samples: ["Hello"],
            tint: .secondary,
            blurb: "A literal label with no data source."),
        .init(
            id: "spacer", title: "Spacer", symbol: "arrow.left.and.right", icon: "",
            format: nil,
            samples: [""],
            tint: .secondary,
            blurb: "Empty width, for pushing things apart.")
    ]

    /// Fills a component in from this template, keeping its identity.
    func apply(to component: inout BarComponent) {
        component.kind = id
        component.title = title
        component.icon = icon
        component.format = format
        component.sampleValues = samples
        if id == "spacer" {
            component.customWidth = 20
            component.boxWidth = 20
            component.paddingOverride = 0
            component.spacingOverride = 0
        }
        if component.text.isEmpty { component.text = samples.first ?? "" }
    }
}

/// Glyphs the picker offers, grouped so the list is scannable.
///
/// These are the sketchybar app font and Nerd Font glyphs the desktop already
/// ships, not arbitrary emoji — anything here renders in the real bar.
enum GlyphCatalogue {
    struct Group: Identifiable {
        let id: String
        let glyphs: [String]
    }

    static let groups: [Group] = [
        .init(
            id: "Shapes",
            glyphs: ["●", "○", "◆", "◇", "■", "□", "▲", "△", "★", "☆", "▮", "▯"]),
        .init(
            id: "Arrows",
            glyphs: ["↑", "↓", "↕", "→", "←", "⇡", "⇣", "⇅", "»", "«"])
    ]
}
