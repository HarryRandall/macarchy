import Foundation

/// Argument arrays are shared by live Apply and startup replay. Custom text is
/// always a value, never executable shell or a SketchyBar command token.
public enum BarCommands {
    public static func replay(
        _ configuration: BarConfiguration, integrations: Integrations
    ) async throws {
        try configuration.validate()
        for component in configuration.components where component.isCustom {
            let query = await integrations.sketchybar(["--query", component.id])
            if !query.ok {
                let result = await integrations.sketchybar(customArguments(component))
                guard result.ok else { throw ConfigurationError(result.summary) }
            }
        }
        let arguments = settings(configuration, startup: true)
        if !arguments.isEmpty {
            let result = await integrations.sketchybar(arguments)
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
    }

    public static func customArguments(_ component: BarComponent) -> [String] {
        ["--add", "item", component.id, component.side]
    }

    public static func settings(
        _ configuration: BarConfiguration, startup: Bool = false
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
            let content = component.members.filter { !$0.hasPrefix("gap.") }
            for gap in component.members where gap.hasPrefix("gap.") {
                args += ["--set", gap, "width=0", "padding_left=0", "padding_right=0"]
            }
            if let first = content.first {
                args += ["--set", first, "padding_left=\(configuration.padding(for: component))"]
            }
            if let last = content.last {
                args += [
                    "--set", last,
                    "padding_right=\(configuration.padding(for: component) + configuration.spacing(for: component))"
                ]
            }
            if component.isCustom { args += customSettings(component) }
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

    private static func customSettings(_ component: BarComponent) -> [String] {
        let spacer = component.kind == "spacer"
        var args = [
            "--set", component.id,
            "icon=\(component.icon)", "label=\(component.text)",
            "icon.drawing=\(!spacer && !component.icon.isEmpty ? "on" : "off")",
            "label.drawing=\(!spacer && !component.text.isEmpty ? "on" : "off")",
            "width=\(spacer ? String(Int(component.customWidth)) : "dynamic")",
            "background.drawing=off", "icon.font=SF Pro:Regular:15", "label.font=SF Pro:Regular:12",
            "icon.padding_left=0", "icon.padding_right=4",
            "label.padding_left=4", "label.padding_right=0", "label.y_offset=0"
        ]
        if let colour = component.colour {
            args += ["icon.color=\(colour)", "label.color=\(colour)"]
        }
        return args
    }

}
