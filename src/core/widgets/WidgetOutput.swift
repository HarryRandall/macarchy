import Foundation

/// What a provider or a built-in reading says the widget should show.
///
/// A provider prints this as JSON, or plain text, which becomes the label.
/// Everything is optional: a provider that only fills `values` lets the
/// manifest's label template decide how they are written out.
public struct WidgetOutput: Equatable, Sendable {
    public var label: String?
    public var icon: String?
    /// The label's colour, as `#rrggbb` or `#rrggbbaa`.
    public var colour: String?
    public var iconColour: String?
    /// A colour for each line of a two-line label, overriding `colour`; a
    /// null keeps the usual one.
    public var lineColours: [String?]?
    /// False hides the widget until a later update shows it again.
    public var drawing: Bool?
    /// Readings for the manifest's label template and dropdown rows.
    public var values: [String: String] = [:]
    /// Dropdown rows that replace the manifest's, for lists that change.
    public var rows: [WidgetMenuRow]?

    public init(label: String? = nil, values: [String: String] = [:]) {
        self.label = label
        self.values = values
    }

    /// Reads what a provider printed. A JSON object is read field by field;
    /// anything else is the label, with its lines joined, since the bar draws one.
    public static func parse(_ text: String) -> WidgetOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(Printed.self, from: data)
        {
            var output = WidgetOutput(label: decoded.label)
            output.icon = decoded.icon
            output.colour = decoded.colour ?? decoded.color
            output.iconColour = decoded.iconColour ?? decoded.iconColor
            output.lineColours = decoded.lineColours ?? decoded.lineColors
            output.drawing = decoded.drawing
            output.values = (decoded.values ?? [:]).mapValues(\.string)
            output.rows = decoded.rows
            return output
        }
        let label = trimmed.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .joined(separator: " ")
        return WidgetOutput(label: label)
    }

    /// The printed JSON. American spellings are accepted too, since authors
    /// coming from SketchyBar will reach for them.
    private struct Printed: Decodable {
        var label: String?
        var icon: String?
        var colour: String?
        var color: String?
        var iconColour: String?
        var iconColor: String?
        var lineColours: [String?]?
        var lineColors: [String?]?
        var drawing: Bool?
        var values: [String: SettingValue]?
        var rows: [WidgetMenuRow]?
    }
}

/// Fills `{name}` placeholders. A name with no value is left as written, so
/// a typo shows on the bar instead of vanishing.
public enum WidgetTemplate {
    public static func render(_ template: String, values: [String: String]) -> String {
        var result = ""
        var name = ""
        var open = false
        for character in template {
            switch (character, open) {
            case ("{", false):
                open = true
                name = ""
            case ("}", true):
                open = false
                result += values[name] ?? "{\(name)}"
            case (_, true):
                name.append(character)
            default:
                result.append(character)
            }
        }
        return open ? result + "{" + name : result
    }
}

/// Colours as SketchyBar takes them.
public enum WidgetColour {
    /// `#rrggbb` or `#rrggbbaa` as SketchyBar's `0xaarrggbb`, or nil when it is neither.
    public static func sketchybar(_ hex: String) -> String? {
        guard hex.matches("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$") else { return nil }
        let digits = hex.dropFirst().lowercased()
        let rgb = digits.prefix(6)
        let alpha = digits.count == 8 ? String(digits.suffix(2)) : "ff"
        return "0x\(alpha)\(rgb)"
    }
}
