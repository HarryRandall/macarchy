import Foundation

/// Widgets drawn as a row of items, one per entry, as Spaces draws one per Space.
extension WidgetLook {
    /// Item `slot` of a row, counting from 1.
    public static func rowID(_ id: String, _ slot: Int) -> String { "\(id).\(slot)" }

    public static func rowMembers(_ id: String, count: Int) -> [String] {
        (1...max(count, 1)).map { rowID(id, $0) }
    }

    /// How many items the widget draws in a row, or nil when it draws one.
    public func rowSlots(_ component: BarComponent) -> Int? {
        guard let manifest = component.widget.flatMap({ manifests[$0] }),
            let row = component.style?.row ?? manifest.style?.row, row > 0
        else { return nil }
        return min(row, WidgetStyle.rowLimit)
    }

    /// Each item laid out as the bar's Spaces always were: the number, then
    /// the apps' glyphs, in a box that only shows when something colours it.
    /// The host fills in what each item says and how it is coloured.
    func rowArguments(
        _ component: BarComponent, manifest: WidgetManifest, style: WidgetStyle, slots: Int,
        click: String
    ) -> [String] {
        let spaces = manifest.source == "spaces"
        let size = style.size ?? 12
        let labelFont =
            spaces ? "sketchybar-app-font:Regular:13.0" : "SF Pro:Semibold:\(Int(size))"
        var arguments: [String] = []
        for slot in 1...slots {
            let id = Self.rowID(component.id, slot)
            arguments += [
                "--set", id, "icon.font=SF Pro:Semibold:\(Int(size))", "label.font=\(labelFont)",
                "icon.padding_left=\(Int(style.paddingLeft ?? 10))", "icon.padding_right=4",
                "label.padding_left=4", "label.padding_right=\(Int(style.paddingRight ?? 20))",
                "icon.y_offset=0", "label.y_offset=-1", "padding_left=2", "padding_right=5",
                "width=dynamic", "background.height=\(Self.boxHeight)",
                "background.corner_radius=\(Int(style.radius ?? 5))",
                spaces ? "click_script=\(command) space \(slot)" : click
            ]
            // The first Space always exists, so its item hears about windows
            // opening, closing and moving between Spaces, and tells the host.
            if spaces && slot == 1 {
                arguments += [
                    "script=\(command) widget trigger windows_changed", "updates=on",
                    "--subscribe", id, "space_windows_change"
                ]
            } else {
                arguments.append("script=")
            }
        }
        arguments += [
            "--set", Self.boxID(component.id), "background.height=\(Self.boxHeight)",
            "background.corner_radius=\(Int(style.radius ?? 5))", "background.padding_left=0",
            "background.padding_right=0", "background.color=0x00000000"
        ]
        return arguments
    }
}
