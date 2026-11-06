import Foundation

extension WidgetHost {
    /// What each of the widget's items is set to for an output: its one
    /// item, or a two-line widget's icon and lines, with its gap and box
    /// shown or hidden alongside, so the whole widget appears at once. Colours fall back to the
    /// widget's style and then the theme's text colour, so a reading that
    /// stops warning goes back to normal.
    static func items(
        _ instance: WidgetInstance, output: WidgetOutput?, look: WidgetLook
    )
        -> [(item: String, properties: [String])]
    {
        let style = instance.style
        if let slots = style.row, slots > 0 {
            return rowItems(instance, output: output, look: look, slots: slots)
        }
        let text =
            output?.colour.flatMap(WidgetColour.sketchybar)
            ?? style.textColour.flatMap(look.colour) ?? look.text
        let iconColour =
            output?.iconColour.flatMap(WidgetColour.sketchybar)
            ?? style.iconColour.flatMap(look.colour) ?? look.text
        let drawing = "drawing=\(output?.drawing == false ? "off" : "on")"
        var icon: [String] = []
        if style.showIcon == false {
            icon += ["icon=", "icon.drawing=off"]
        } else if let glyph = output?.icon.map({ clean($0) }) {
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
            (WidgetLook.gapID(instance.id), [drawing]), (instance.id, icon + [drawing]),
            (WidgetLook.linesID(instance.id), lines + [drawing]),
            (WidgetLook.boxID(instance.id), [drawing])
        ]
    }

    /// A row's items, each from its entry in the output's `items`: hidden
    /// when it has none, and its box drawn when the entry colours it. The
    /// row's own box shows when the output gives it a border or background.
    static func rowItems(
        _ instance: WidgetInstance, output: WidgetOutput?, look: WidgetLook, slots: Int
    ) -> [(item: String, properties: [String])] {
        let entries = output?.items ?? []
        let fallback = instance.style.textColour.flatMap(look.colour) ?? look.text
        func paint(_ name: String?) -> String? {
            name.flatMap(look.colour) ?? (name == "text" ? look.text : nil)
        }
        var items: [(item: String, properties: [String])] = (1...min(slots, WidgetStyle.rowLimit))
            .map { slot in
                let id = WidgetLook.rowID(instance.id, slot)
                guard entries.indices.contains(slot - 1), entries[slot - 1].drawing != false else {
                    return (id, ["drawing=off"])
                }
                let entry = entries[slot - 1]
                let icon = instance.style.showIcon == false ? "" : clean(entry.icon ?? "")
                // Leading spaces are kept: a row lines its items up with them.
                let label = clean(entry.label ?? "", trimmingLeading: false)
                var properties = [
                    "drawing=on", "icon=\(icon)", "icon.drawing=\(icon.isEmpty ? "off" : "on")",
                    "label=\(label)", "label.drawing=\(label.isEmpty ? "off" : "on")"
                ]
                if let colour = paint(entry.iconColour) ?? paint(entry.colour) ?? fallback {
                    properties.append("icon.color=\(colour)")
                }
                if let colour = paint(entry.colour) ?? fallback {
                    properties.append("label.color=\(colour)")
                }
                properties += box(background: paint(entry.background), border: paint(entry.border))
                if let display = entry.display { properties.append("display=\(display)") }
                return (id, properties)
            }
        let background = paint(output?.background)
        let border = paint(output?.border)
        items.append(
            (
                WidgetLook.boxID(instance.id),
                ["drawing=\(background != nil || border != nil ? "on" : "off")"]
                    + box(background: background, border: border)
            ))
        return items
    }

    /// A box behind an item: the background faint, as a tint, and a thin border.
    private static func box(background: String?, border: String?) -> [String] {
        [
            "background.drawing=\(background != nil || border != nil ? "on" : "off")",
            "background.color=\(background.map { tint($0) } ?? "0x00000000")",
            "background.border_width=\(border == nil ? 0 : 1)",
            "background.border_color=\(border ?? "0x00000000")"
        ]
    }

    /// A SketchyBar colour at a tenth of its strength, unless it already
    /// says how strong it is.
    static func tint(_ colour: String) -> String {
        guard colour.count == 10, colour.hasPrefix("0xff") else { return colour }
        return "0x1a" + colour.dropFirst(4)
    }

    /// The label for an output, or the unavailable sample when there has never been one.
    static func label(_ instance: WidgetInstance, output: WidgetOutput?) -> String {
        guard let output else { return instance.manifest.samples?.unavailable ?? "--" }
        let values = instance.settings.mapValues(\.string).merging(output.values) { $1 }
        return output.label
            ?? WidgetTemplate.render(instance.manifest.label ?? "", values: values)
    }

    /// One line, no control characters, and short enough for a bar.
    static func clean(_ text: String, trimmingLeading: Bool = true) -> String {
        let line = text.unicodeScalars.map { scalar -> String in
            CharacterSet.newlines.contains(scalar)
                ? " "
                : CharacterSet.controlCharacters.contains(scalar) ? "" : String(scalar)
        }.joined()
        let trimmed =
            trimmingLeading
            ? line.trimmingCharacters(in: .whitespaces)
            : String(line.reversed().drop(while: \.isWhitespace).reversed())
        return String(trimmed.prefix(200))
    }
}
