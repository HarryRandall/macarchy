import Foundation

/// Argument arrays are shared by live Apply and startup replay. Custom text is
/// always a value, never executable shell or a SketchyBar command token.
public enum BarCommands {
    public static func replay(
        _ configuration: BarConfiguration, integrations: Integrations,
        widgets: WidgetLook? = nil
    ) async throws {
        try configuration.validate()
        let hasWidgets = configuration.components.contains(where: \.isWidget)
        let widgets = widgets ?? (hasWidgets ? WidgetLook.current() : WidgetLook())
        for component in configuration.components where component.ownsItem {
            let query = await integrations.sketchybar(["--query", component.id])
            if !query.ok {
                let result = await integrations.sketchybar(customArguments(component))
                guard result.ok else { throw ConfigurationError(result.summary) }
            }
        }
        for component in configuration.components where component.hasBoxLayout {
            for member in component.members where member.hasPrefix("gap.") {
                let query = await integrations.sketchybar(["--query", member])
                if !query.ok {
                    let result = await integrations.sketchybar([
                        "--add", "item", member, component.side, "--set", member,
                        "icon.drawing=off", "label.drawing=off"
                    ])
                    guard result.ok else { throw ConfigurationError(result.summary) }
                }
            }
        }
        let arguments = settings(configuration, startup: true, widgets: widgets)
        if !arguments.isEmpty {
            let result = await integrations.sketchybar(arguments)
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
    }

    public static func customArguments(_ component: BarComponent) -> [String] {
        ["--add", "item", component.id, component.side]
    }

    /// What a made item shows, or how a widget's item looks. Native items
    /// keep what their own scripts set.
    private static func itemSettings(_ component: BarComponent, widgets: WidgetLook) -> [String] {
        if component.isCustom { return customSettings(component) }
        if component.isWidget { return widgets.arguments(for: component) }
        return []
    }

    public static func settings(
        _ configuration: BarConfiguration, startup: Bool = false, widgets: WidgetLook = WidgetLook()
    ) -> [String] {
        var args: [String] = []
        if !configuration.geometry.isEmpty {
            args +=
                ["--bar"]
                + configuration.geometry.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        }
        for component in configuration.components {
            for member in component.members {
                args += ["--set", member, "position=\(component.side)"]
                if component.id != "workspaces" || !startup || !component.visible {
                    let drawing = component.visible && (component.drawing[member] ?? true)
                    args.append("drawing=\(drawing ? "on" : "off")")
                }
            }
            for bracket in component.brackets {
                args += ["--set", bracket, "drawing=\(component.visible ? "on" : "off")"]
            }
            if component.id == "workspaces" {
                args += [
                    "--set", "space_labels_updater", "updates=\(component.visible ? "on" : "off")"
                ]
            }
            args += spacingSettings(component, configuration: configuration)
            args += itemSettings(component, widgets: widgets)
            args += appearanceSettings(component)
            var presentation = nativePresentation(component.presentation)
            if component.hasBoxLayout {
                for gap in component.members where gap.hasPrefix("gap.") {
                    presentation[gap, default: [:]]["width"] = String(
                        configuration.spacing(for: component))
                }
            }
            for member in presentation.keys.sorted() {
                let values = presentation[member] ?? [:]
                args +=
                    ["--set", member]
                    + values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            }
        }
        for side in ["left", "center", "right"] {
            let members = configuration.components.filter { $0.side == side }.flatMap(\.members)
            let ordered = side == "right" ? Array(members.reversed()) : members
            for pair in zip(ordered, ordered.dropFirst()) {
                args += ["--move", pair.1, "after", pair.0]
            }
        }
        return args
    }

    private static func spacingSettings(
        _ component: BarComponent, configuration: BarConfiguration
    ) -> [String] {
        var args: [String] = []
        let content = component.members.filter { !$0.hasPrefix("gap.") }
        if component.paddingOverride != nil || configuration.componentPadding != nil,
            let first = content.first
        {
            args += [
                "--set", first,
                "padding_left=\(component.hasBoxLayout ? 0 : configuration.padding(for: component))"
            ]
        }
        if component.spacingOverride != nil || configuration.componentSpacing != nil {
            if let gap = component.members.first(where: { $0.hasPrefix("gap.") }) {
                args += ["--set", gap, "width=\(configuration.spacing(for: component))"]
                if component.hasBoxLayout { args += ["padding_left=0", "padding_right=0"] }
            } else if let last = content.last {
                args += [
                    "--set", last,
                    "padding_right=\(configuration.spacing(for: component))"
                ]
            }
        }
        return args
    }

    static func customSettings(_ component: BarComponent) -> [String] {
        let spacer = component.kind == "spacer"
        let command = component.kind == "command"
        // The label goes through `rendered` so a format like "{value}%" is
        // what lands on the bar rather than the bare text.
        let label = component.rendered(component.text)
        return [
            "--set", component.id,
            "icon=\(component.icon)", "label=\(label)",
            "icon.drawing=\(!spacer && !component.icon.isEmpty ? "on" : "off")",
            "label.drawing=\(command || (!spacer && !label.isEmpty) ? "on" : "off")",
            "width=\(component.boxWidth.map { String($0) } ?? (spacer ? String(Int(component.customWidth)) : "dynamic"))",
            "icon.font=SF Pro:Regular:15", "label.font=SF Pro:Regular:12",
            "icon.padding_left=0", "icon.padding_right=\(spacer ? 0 : 4)",
            "label.padding_left=\(spacer ? 0 : 4)", "label.padding_right=0", "label.y_offset=0"
        ] + (spacer ? ["padding_left=0", "padding_right=0", "background.drawing=off"] : [])
            + (command ? commandSettings(component) : [])
    }

    /// SketchyBar runs the script through `sh` every `interval` seconds; the
    /// command's output becomes the label.
    static func commandSettings(_ component: BarComponent) -> [String] {
        let bar = "'" + Paths.sketchybar.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let script = "\(bar) --set \"$NAME\" label=\"$(\(component.command ?? "true"))\""
        return ["script=\(script)", "update_freq=\(component.interval ?? 30)", "updates=on"]
    }

    /// Colours and the fill behind a component, for every component.
    ///
    /// These used to sit inside `customSettings`, which only ran for
    /// components someone had added by hand — so styling a widget that ships
    /// with the bar emitted no commands at all, and Apply reported success
    /// having changed nothing.
    ///
    /// Leaves carry the text colours; the fill and its radius go on the
    /// bracket, because that is what SketchyBar draws a group background on.
    private static func appearanceSettings(_ component: BarComponent) -> [String] {
        var args: [String] = []
        let leaves =
            component.ownsItem
            ? [component.id]
            : component.members.filter { !$0.hasPrefix("gap.") }

        let iconColour = component.iconColour ?? component.colour
        for leaf in leaves {
            var settings: [String] = []
            if let iconColour { settings.append("icon.color=\(iconColour)") }
            if let colour = component.colour { settings.append("label.color=\(colour)") }
            if !settings.isEmpty { args += ["--set", leaf] + settings }
        }

        // A custom or widget component is its own item, so it carries its own fill.
        let fillTargets = component.ownsItem ? [component.id] : component.brackets
        for target in fillTargets {
            if let fill = component.backgroundColour {
                args += [
                    "--set", target, "background.drawing=on", "background.color=\(fill)",
                    "background.corner_radius=\(Int(component.cornerRadius))"
                ]
            } else if component.isCustom {
                args += ["--set", target, "background.drawing=off"]
            }
        }
        return args
    }
}
