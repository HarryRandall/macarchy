import Foundation
import SwiftUI

/// The terminal half of a theme, read from its ghostty.conf.
///
/// Every theme ships one with a background, a foreground and all 16 ANSI
/// slots, which is enough to render a faithful terminal preview rather than an
/// approximation built from the border colour.
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

    static func load(from directory: URL) -> GhosttyPalette? {
        let url = directory.appending(path: "ghostty.conf")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var palette = GhosttyPalette()
        var slots: [Int: Color] = [:]

        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                let eq = line.firstIndex(of: "=")
            else { continue }
            let key = line[line.startIndex..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            switch key {
            case "background": palette.background = Color(macarchyHex: value) ?? palette.background
            case "foreground": palette.foreground = Color(macarchyHex: value) ?? palette.foreground
            case "cursor-color": palette.cursor = Color(macarchyHex: value) ?? palette.cursor
            case "palette":
                // "palette = 4=#e68e0d" — the slot index is on the value side.
                let parts = value.split(separator: "=", maxSplits: 1)
                guard parts.count == 2,
                    let index = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                    let color = Color(
                        macarchyHex: String(parts[1]).trimmingCharacters(in: .whitespaces))
                else { continue }
                slots[index] = color
            default: break
            }
        }

        guard !slots.isEmpty else { return palette }
        palette.ansi = (0...15).map { slots[$0] ?? palette.foreground }
        return palette
    }
}
