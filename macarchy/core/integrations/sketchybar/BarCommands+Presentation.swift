import Foundation

extension BarCommands {
    /// Live Apply changes presentation without replacing a widget's source.
    public static func changes(
        _ configuration: BarConfiguration, from previous: BarConfiguration,
        baseline: [String: [String: String]]
    ) -> [String] {
        var args: [String] = []
        let geometry = configuration.geometry.filter { previous.geometry[$0.key] != $0.value }
        if !geometry.isEmpty {
            args += ["--bar"] + geometry.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        }
        for component in configuration.components {
            let old = previous.components.first { $0.id == component.id }
            var edits: [String: [String: String]] = [:]
            if old?.side != component.side {
                for member in component.members {
                    edits[member, default: [:]]["position"] = component.side
                }
            }
            if old?.visible != component.visible {
                for member in component.members + component.brackets {
                    let drawing = component.visible && (component.drawing[member] ?? true)
                    edits[member, default: [:]]["drawing"] = drawing ? "on" : "off"
                }
            }
            for (member, values) in presentationChanges(component, old: old) {
                edits[member, default: [:]].merge(values) { _, new in new }
            }
            let spacing = spacingChanges(
                component, old: old, configuration: configuration, previous: previous,
                baseline: baseline)
            for (member, values) in spacing {
                edits[member, default: [:]].merge(values) { _, new in new }
            }
            if component.isCustom
                && (old == nil || old?.text != component.text || old?.icon != component.icon
                    || old?.format != component.format || old?.customWidth != component.customWidth
                    || old?.boxWidth != component.boxWidth)
            {
                args += customSettings(component)
            }
            for member in edits.keys.sorted() {
                guard let values = edits[member], !values.isEmpty else { continue }
                args +=
                    ["--set", member]
                    + values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            }
        }
        args += orderChanges(configuration, previous: previous)
        return args
    }

    private static func orderChanges(
        _ configuration: BarConfiguration, previous: BarConfiguration
    ) -> [String] {
        var args: [String] = []
        let order = configuration.components.map {
            "\($0.id):\($0.side):\($0.members.joined(separator: ","))"
        }
        if order
            != previous.components.map({
                "\($0.id):\($0.side):\($0.members.joined(separator: ","))"
            })
        {
            for side in ["left", "center", "right"] {
                let members = configuration.components.filter { $0.side == side }.flatMap(\.members)
                let ordered = side == "right" ? Array(members.reversed()) : members
                for pair in zip(ordered, ordered.dropFirst()) {
                    args += ["--move", pair.1, "after", pair.0]
                }
            }
        }
        return args
    }

    private static func presentationChanges(
        _ component: BarComponent, old: BarComponent?
    ) -> [String: [String: String]] {
        var edits: [String: [String: String]] = [:]
        let before = old.map(presentationSettings) ?? [:]
        let after = presentationSettings(component)
        for member in Set(before.keys).union(after.keys) {
            for key in Set(before[member, default: [:]].keys).union(
                after[member, default: [:]].keys)
            {
                let value = after[member]?[key]
                guard value != before[member]?[key] else { continue }
                if let resolved = value ?? component.presentationDefaults[member]?[key] {
                    edits[member, default: [:]][key] = resolved
                }
            }
        }
        return edits
    }

    private static func spacingChanges(
        _ component: BarComponent, old: BarComponent?, configuration: BarConfiguration,
        previous: BarConfiguration, baseline: [String: [String: String]]
    ) -> [String: [String: String]] {
        var edits: [String: [String: String]] = [:]
        if old?.paddingOverride != component.paddingOverride
            || previous.componentPadding != configuration.componentPadding
        {
            if let first = component.members.first(where: { !$0.hasPrefix("gap.") }) {
                edits[first, default: [:]]["padding_left"] =
                    component.hasBoxLayout
                    ? "0"
                    : String(
                        configuration.padding(for: component))
            }
        }
        if old?.spacingOverride != component.spacingOverride
            || previous.componentSpacing != configuration.componentSpacing
            || old?.hasBoxLayout != component.hasBoxLayout
        {
            let gap = component.members.first { $0.hasPrefix("gap.") }
            if let gap {
                edits[gap, default: [:]]["width"] = String(
                    configuration.spacing(for: component))
                if component.hasBoxLayout {
                    edits[gap, default: [:]]["padding_left"] = "0"
                    edits[gap, default: [:]]["padding_right"] = "0"
                }
            } else if let last = component.members.last {
                let original =
                    component.presentationDefaults[last]?["padding_right"]
                    ?? baseline[last]?["padding_right"] ?? "0"
                let base = component.nativeTrailingPadding ?? Double(original) ?? 0
                edits[last, default: [:]]["padding_right"] = String(
                    component.spacingOverride != nil || configuration.componentSpacing != nil
                        ? configuration.spacing(for: component) : base)
            }
        }
        return edits
    }

    /// Stacked rows need independent zero-length native slots. Positive row
    /// widths enlarge the drawing window even when the containing item is fixed.
    static func nativePresentation(
        _ presentation: [String: [String: String]]
    ) -> [String: [String: String]] {
        presentation.mapValues { original in
            var values = original
            var preceding = 0.0
            var converted = 0.0
            for layer in ["icon", "label"] {
                let width = Double(original[layer + ".width"] ?? "") ?? 0
                let left = Double(original[layer + ".padding_left"] ?? "") ?? 0
                let right = Double(original[layer + ".padding_right"] ?? "") ?? 0
                if original[layer + ".align"] == "right", width > 0, left + right == 0 {
                    let end = preceding + width - right
                    values[layer + ".width"] = "0"
                    values[layer + ".padding_left"] = String(end)
                    values[layer + ".padding_right"] = String(-end)
                    converted += width
                } else if converted != 0, original[layer + ".padding_left"] != nil {
                    values[layer + ".padding_left"] = String(left + converted)
                }
                preceding += width
            }
            return values
        }
    }

    static func presentationSettings(_ component: BarComponent) -> [String: [String: String]] {
        var result = nativePresentation(component.presentation)
        for member in component.members where !member.hasPrefix("gap.") {
            if let colour = component.colour {
                result[member, default: [:]]["label.color"] = colour
                result[member, default: [:]]["icon.color"] = component.iconColour ?? colour
            } else if let colour = component.iconColour {
                result[member, default: [:]]["icon.color"] = colour
            }
        }
        if let colour = component.backgroundColour {
            for member in component.isCustom ? [component.id] : component.brackets {
                result[member, default: [:]]["background.color"] = colour
                result[member, default: [:]]["background.drawing"] = "on"
                result[member, default: [:]]["background.corner_radius"] = String(
                    component.cornerRadius)
            }
        }
        return result
    }
}
