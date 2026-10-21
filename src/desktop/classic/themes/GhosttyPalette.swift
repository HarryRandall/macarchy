import Foundation
import Macarchy
import SwiftUI

/// `TerminalPalette` as SwiftUI colours, for the previews that draw a terminal.
struct GhosttyPalette: Sendable {
    var background: Color = .black
    var foreground: Color = .white
    var cursor: Color = .white
    var ansi: [Color] = []

    /// ANSI slots by their conventional meaning, falling back to the
    /// foreground when a theme leaves a slot undefined.
    func ansi(_ index: Int) -> Color {
        guard index >= 0, index < ansi.count else { return foreground }
        return ansi[index]
    }

    var red: Color { ansi(1) }
    var green: Color { ansi(2) }
    var yellow: Color { ansi(3) }
    var blue: Color { ansi(4) }
    var magenta: Color { ansi(5) }
    var cyan: Color { ansi(6) }
    var brightBlack: Color { ansi(8) }

    init(_ palette: TerminalPalette) {
        background = Color(macarchyHex: palette.background) ?? .black
        foreground = Color(macarchyHex: palette.foreground) ?? .white
        cursor = Color(macarchyHex: palette.cursor) ?? .white
        ansi = palette.ansi.map { Color(macarchyHex: $0) ?? foreground }
    }
}
