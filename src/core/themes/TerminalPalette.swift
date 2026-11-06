import Foundation

/// The terminal half of a theme, read from its ghostty.conf as `#rrggbb`.
///
/// Every theme ships a background, a foreground and all 16 ANSI slots, which
/// is enough to render a faithful preview rather than an approximation built
/// from the border colour.
public struct TerminalPalette: Sendable, Equatable {
    public var background = "#000000"
    public var foreground = "#ffffff"
    public var cursor = "#ffffff"
    /// Empty when the file defines no slots.
    public var ansi: [String] = []

    public init() {}

    /// An ANSI slot by its conventional index, falling back to the foreground
    /// when a theme leaves it undefined.
    public func ansi(_ index: Int) -> String {
        ansi.indices.contains(index) ? ansi[index] : foreground
    }

    public static func load(from directory: URL) -> TerminalPalette? {
        let url = directory.appending(path: "ghostty.conf")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(text)
    }

    public static func parse(_ text: String) -> TerminalPalette {
        var palette = TerminalPalette()
        var slots: [Int: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else {
                continue
            }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "background": palette.background = rgb(value) ?? palette.background
            case "foreground": palette.foreground = rgb(value) ?? palette.foreground
            case "cursor-color": palette.cursor = rgb(value) ?? palette.cursor
            case "palette":
                // "palette = 4=#e68e0d": the slot index is on the value side.
                let parts = value.split(separator: "=", maxSplits: 1)
                guard parts.count == 2,
                    let index = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                    let colour = rgb(String(parts[1]))
                else { continue }
                slots[index] = colour
            default: break
            }
        }
        if !slots.isEmpty {
            palette.ansi = (0...15).map { slots[$0] ?? palette.foreground }
        }
        return palette
    }

    /// Normalises `#rgb`-style theme colours to `#rrggbb`. Accepts `#RRGGBB`,
    /// bare `RRGGBB` and the `0xAARRGGBB` form borders and SketchyBar use,
    /// whose alpha is dropped.
    public static func rgb(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return nil
        }
        if text.lowercased().hasPrefix("0x") { text = String(text.dropFirst(2)) }
        if text.hasPrefix("#") { text = String(text.dropFirst()) }
        guard text.count == 6 || text.count == 8, UInt64(text, radix: 16) != nil else {
            return nil
        }
        return "#" + text.suffix(6).lowercased()
    }
}
