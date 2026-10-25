import Foundation

extension WidgetMenuRow {
    /// A problem with one row: the field it is in, if any, and what it is.
    private typealias Note = (field: String?, message: String)

    func findings(index: Int, settings: [String: WidgetSetting]) -> [WidgetFinding] {
        let path = ["click", "dropdown", String(index)]
        let notes: [Note] =
            Self.types.contains(type)
            ? templateNotes() + typeNotes(settings: settings) + misplacedNotes()
            : [("type", "has type \"\(type)\"; use one of \(Self.types.joined(separator: ", "))")]
        return notes.map { note in
            WidgetFinding(
                note.field.map { path + [$0] } ?? path, "dropdown row \(index + 1) \(note.message)")
        }
    }

    private var hasLabel: Bool { !(label ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasValue: Bool { !(value ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    private var needsLabel: [Note] { hasLabel ? [] : [("label", "needs a label")] }

    private func templateNotes() -> [Note] {
        let templates: [(field: String, text: String?)] = [
            ("label", label), ("value", value), ("current", current), ("when", when),
            ("min", min), ("max", max)
        ]
        return templates.compactMap { field, text -> Note? in
            guard let text, let problem = templateProblem(text) else { return nil }
            return (field, "\(field) \(problem)")
        }
    }

    private func typeNotes(settings: [String: WidgetSetting]) -> [Note] {
        switch type {
        case "heading", "text", "status":
            return needsLabel
        case "reading":
            return needsLabel + (hasValue ? [] : [("value", "needs a value")])
        case "action":
            return needsLabel
                + ((run == nil) == (open == nil) ? [(nil, "needs one of run or open")] : [])
        case "toggle", "choice":
            return settingNotes(settings: settings)
        case "graph", "mirror", "map", "cores", "apps":
            return hasValue ? [] : [("value", "needs the reading it shows, such as {history}")]
        default:
            let empty = !hasLabel && !hasValue && run == nil && open == nil && setting == nil
            return empty ? [] : [(nil, "is a divider, which has nothing else")]
        }
    }

    /// A toggle changes a toggle setting. A choice changes a choice setting,
    /// or shows a reading against its options.
    private func settingNotes(settings: [String: WidgetSetting]) -> [Note] {
        let label = type == "toggle" ? needsLabel : []
        guard let setting else {
            if type == "toggle" {
                return label + [("setting", "needs the toggle setting it changes")]
            }
            return hasValue && !(options ?? []).isEmpty
                ? [] : [(nil, "needs a choice setting, or a value and its options")]
        }
        return settings[setting]?.type == type
            ? label : label + [("setting", "changes \(setting), which is not a \(type) setting")]
    }

    private func misplacedNotes() -> [Note] {
        var notes: [Note] = []
        if type != "action", run != nil || open != nil {
            notes.append((nil, "can only run or open something if it is an action"))
        }
        if icons != nil, !["choice", "status"].contains(type) {
            notes.append(("icons", "can only have icons if it is a choice or status"))
        }
        if !["toggle", "choice"].contains(type), setting != nil {
            notes.append(("setting", "can only change a setting if it is a toggle or choice"))
        }
        let present = [
            "current": current != nil, "colour": colour != nil, "unit": unit != nil,
            "min": min != nil, "max": max != nil, "cells": cells != nil
        ]
        let allowed: [(field: String, types: [String])] = [
            ("current", ["graph", "mirror", "status"]), ("colour", ["graph", "mirror", "map"]),
            ("unit", ["graph", "mirror", "map"]), ("min", ["graph", "map"]),
            ("max", ["graph", "map"]), ("cells", ["map"])
        ]
        for rule in allowed where present[rule.field] == true && !rule.types.contains(type) {
            let kinds = rule.types.count == 1 ? "a \(rule.types[0])" : Self.either(rule.types)
            let field = rule.field == "cells" ? "cells" : "a \(rule.field)"
            notes.append((rule.field, "can only have \(field) if it is \(kinds)"))
        }
        if let colour,
            colour.split(separator: "|", omittingEmptySubsequences: false).contains(where: {
                !Self.graphColours.contains(String($0))
                    && !String($0).matches("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
            })
        {
            notes.append(
                ("colour", "colour should be accent, temperature or a colour such as #a5b4fc"))
        }
        if let unit, unit.count > 4 || unit.contains("{") {
            notes.append(("unit", "unit should be short, such as %, °, W or GB"))
        }
        if let cells, !(16...192).contains(cells) {
            notes.append(("cells", "cells should be between 16 and 192"))
        }
        return notes
    }

    /// `a graph, mirror or status`.
    private static func either(_ types: [String]) -> String {
        "a " + types.dropLast().joined(separator: ", ") + " or " + (types.last ?? "")
    }
}
