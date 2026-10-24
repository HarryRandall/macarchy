import Foundation

extension WidgetHost {
    /// What each of the widget's items is set to for an output: its one
    /// item, or a two-line widget's icon and lines. Colours fall back to the
    /// widget's style and then the theme's text colour, so a reading that
    /// stops warning goes back to normal.
    static func items(
        _ instance: WidgetInstance, output: WidgetOutput?, look: WidgetLook
    )
        -> [(item: String, properties: [String])]
    {
        let style = instance.style
        let text =
            output?.colour.flatMap(WidgetColour.sketchybar)
            ?? style.textColour.flatMap(look.colour) ?? look.text
        let iconColour =
            output?.iconColour.flatMap(WidgetColour.sketchybar)
            ?? style.iconColour.flatMap(look.colour) ?? look.text
        let drawing = "drawing=\(output?.drawing == false ? "off" : "on")"
        var icon: [String] = []
        if let glyph = output?.icon.map(clean) {
            icon += ["icon=\(glyph)", "icon.drawing=\(glyph.isEmpty ? "off" : "on")"]
        }
        if let iconColour { icon.append("icon.color=\(iconColour)") }
        let raw = label(instance, output: output)
        guard style.lines == 2 else {
            let shown = clean(raw)
            var properties =
                ["label=\(shown)", "label.drawing=\(shown.isEmpty ? "off" : "on")"] + icon
            if let text { properties.append("label.color=\(text)") }
            return [(instance.id, properties + [drawing])]
        }
        let parts = raw.split(separator: "\n", omittingEmptySubsequences: false).map {
            clean(String($0))
        }
        let colours = output?.lineColours ?? []
        func colour(_ line: Int) -> String? {
            (colours.indices.contains(line) ? colours[line].flatMap(WidgetColour.sketchybar) : nil)
                ?? text
        }
        var lines = ["icon=\(parts.first ?? "")", "label=\(parts.count > 1 ? parts[1] : "")"]
        if let first = colour(0) { lines.append("icon.color=\(first)") }
        if let second = colour(1) { lines.append("label.color=\(second)") }
        return [
            (instance.id, icon + [drawing]), (WidgetLook.linesID(instance.id), lines + [drawing])
        ]
    }

    /// The label for an output, or the unavailable sample when there has never been one.
    static func label(_ instance: WidgetInstance, output: WidgetOutput?) -> String {
        guard let output else { return instance.manifest.samples?.unavailable ?? "--" }
        let values = instance.settings.mapValues(\.string).merging(output.values) { $1 }
        return output.label
            ?? WidgetTemplate.render(instance.manifest.label ?? "", values: values)
    }

    /// One line, no control characters, and short enough for a bar.
    static func clean(_ text: String) -> String {
        let line = text.unicodeScalars.map { scalar -> String in
            CharacterSet.newlines.contains(scalar)
                ? " "
                : CharacterSet.controlCharacters.contains(scalar) ? "" : String(scalar)
        }.joined()
        return String(line.trimmingCharacters(in: .whitespaces).prefix(200))
    }
}
