import Foundation

/// How each widget's item is drawn: what `BarCommands` needs to know about
/// widgets, gathered once so building the commands stays a pure step.
///
/// The host owns what an item says; this owns how it looks and what clicking
/// it does. A component's own colour overrides are applied after these, so an
/// edit on the Menu Bar page wins over the widget's defaults.
public struct WidgetLook: Sendable {
    public var manifests: [String: WidgetManifest]
    /// The theme's accent, for styles that ask for `accent`.
    public var accent: String?
    /// The theme's text colour, dimmed, for styles that ask for `muted`.
    public var muted: String?
    /// The theme's text colour, which a reading goes back to after a warning colour.
    public var text: String?
    /// How the bar reaches the CLI when a widget is clicked.
    public var command = Paths.cliInShell
    var gap = 6
    var inset = 8.0
    var boxHeight = 24

    public func configured(_ configuration: BarConfiguration) -> WidgetLook {
        var look = self
        look.gap = configuration.widgetGap ?? 6
        look.inset = Double(configuration.widgetInset ?? 8)
        look.boxHeight = configuration.widgetHeight ?? 24
        return look
    }

    public init(
        manifests: [String: WidgetManifest] = [:], accent: String? = nil, muted: String? = nil,
        text: String? = nil
    ) {
        self.manifests = manifests
        self.accent = accent
        self.muted = muted
        self.text = text
    }

    /// The widgets on this Mac and the active theme's colours.
    public static func current(
        catalogue: WidgetCatalogue = WidgetCatalogue(), store: SettingsStore = SettingsStore()
    ) -> WidgetLook {
        let name = (try? store.read())?.currentTheme
        let theme = name.flatMap { Theme.load(from: Paths.themesDirectory.appending(path: $0)) }
        return current(
            catalogue: catalogue, theme: theme,
            text: theme == nil ? nil : BarLook.Colours.theme(name).text)
    }

    /// The widgets on this Mac in `theme`'s colours, as while a theme is
    /// being applied and before settings name it. `text` is the bar's text
    /// colour when the caller has it: a theme without `sketchybarText` still
    /// gives the bar one from its terminal colours, and a widget needs it to
    /// go back to normal after a warning colour.
    public static func current(
        catalogue: WidgetCatalogue = WidgetCatalogue(), theme: Theme?, text: String? = nil
    )
        -> WidgetLook
    {
        let manifests = Dictionary(
            catalogue.read().entries.map { ($0.id, $0.manifest) },
            uniquingKeysWith: { first, _ in first })
        // SketchyBar reads 0xAARRGGBB only; a theme may spell #rrggbb.
        let text = text ?? theme?.colors.sketchybarText.map(Theme.argb)
        let muted = text.flatMap {
            $0.count == 10 && $0.hasPrefix("0x") ? "0x99" + $0.dropFirst(4) : nil
        }
        var look = WidgetLook(
            manifests: manifests, accent: theme?.colors.borderActive.map(Theme.argb), muted: muted,
            text: text)
        if let command = isolatedCommand() { look.command = command }
        return look
    }

    /// An isolated copy's clicks must reach its own CLI with its own home:
    /// the installed CLI behind the app link reads the real home, and the
    /// installed app ignores notices from other homes.
    static func isolatedCommand(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isolated: Bool = Paths.isolated,
        executable: URL? = Bundle.main.executableURL
    ) -> String? {
        guard isolated, let folder = executable?.deletingLastPathComponent() else { return nil }
        let cli = folder.appending(path: "macarchy")
        let variables = ["MACARCHY_HOME", "MACARCHY_SEARCH_PATH"].compactMap { name in
            environment[name].map { "\(name)=\(Shell.quote($0)) " }
        }
        return variables.joined() + Shell.quote(cli.path)
    }

    // MARK: - Items

    /// The item a two-line widget writes its lines into, beside its icon.
    public static func linesID(_ id: String) -> String { id + ".lines" }
    /// The bracket that draws a two-line widget's box around both items.
    public static func boxID(_ id: String) -> String { id + ".box" }
    /// The empty item left of a two-line widget's box. SketchyBar draws a
    /// bracket over its outer items' padding, so the gap needs its own item.
    public static func gapID(_ id: String) -> String { id + ".gap" }

    /// A two-line widget's items, left to right.
    public static func stackedMembers(_ id: String) -> [String] {
        [Self.gapID(id), id, linesID(id)]
    }

    /// The items a widget's box goes around: all but its gap.
    public static func boxed(_ component: BarComponent) -> [String] {
        component.members.filter { $0 != Self.gapID(component.id) }
    }

    /// Points between a widget's icon and its text.
    static let spacing = 6

    /// How wide a character of the stacked lines' font is, in points.
    static let characterWidth = 6

    /// The characters in a two-line widget's widest sample line, which sets
    /// the width of its column.
    public static func columnCharacters(_ manifest: WidgetManifest) -> Int {
        let widest = (manifest.samples?.widest ?? "100.0%").split(separator: "\n").map(\.count)
        return max(widest.max() ?? 6, 3)
    }

    /// Whether the widget stacks its label's two lines beside its icon.
    public func isStacked(_ component: BarComponent) -> Bool {
        guard let manifest = component.widget.flatMap({ manifests[$0] }) else { return false }
        return (component.style?.lines ?? manifest.style?.lines) == 2
    }

    /// The bar with each widget component made of the items its widget
    /// needs: one item, a two-line widget's icon, lines and box, or a row's
    /// items and box.
    public func normalised(_ configuration: BarConfiguration) -> BarConfiguration {
        var result = configuration
        for index in result.components.indices where result.components[index].isWidget {
            let id = result.components[index].id
            if let slots = rowSlots(result.components[index]) {
                result.components[index].members = Self.rowMembers(id, count: slots)
                result.components[index].brackets = [Self.boxID(id)]
                continue
            }
            let stacked = isStacked(result.components[index])
            result.components[index].members = stacked ? Self.stackedMembers(id) : [id]
            result.components[index].brackets = stacked ? [Self.boxID(id)] : []
        }
        return result
    }

    /// The commands that draw `component`'s widget, or none when the widget
    /// is unknown, in which case the item is left as it is.
    public func arguments(for component: BarComponent) -> [String] {
        guard let widget = component.widget, let manifest = manifests[widget] else { return [] }
        let style = (component.style ?? WidgetStyle()).over(manifest.style)
        let icon = style.showIcon == false ? "" : (manifest.icon ?? "")
        let size = style.size ?? 12
        let clicks = (component.click ?? manifest.click) != nil
        let click =
            "click_script="
            + (clicks ? "\(command) widget click \(Shell.quote(component.id))" : "")
        var properties = [
            "icon=\(icon)", "icon.drawing=\(icon.isEmpty ? "off" : "on")",
            "icon.font=SF Pro:Semibold:\(Self.points(size + 3))", "script=", click
        ]
        if let colour = style.iconColour.flatMap(colour) {
            properties.append("icon.color=\(colour)")
        }
        if let slots = rowSlots(component) {
            return rowArguments(
                component, manifest: manifest, style: style, slots: slots, click: click)
        }
        if isStacked(component) {
            return stackedArguments(component, manifest: manifest, style: style, icon: properties)
        }
        let left = Int(style.paddingLeft ?? inset)
        let right = Int(style.paddingRight ?? inset)
        properties += [
            "label.font=SF Pro:Semibold:\(Self.points(size))", "width=dynamic",
            "padding_left=\(gap)", "padding_right=0", "icon.padding_left=\(left)",
            "icon.padding_right=\(Self.spacing)",
            "label.padding_left=\(icon.isEmpty ? left : 0)", "label.padding_right=\(right)",
            "icon.y_offset=0", "label.y_offset=1",
            "background.height=\(boxHeight)",
            "background.corner_radius=\(Int(style.radius ?? 5))"
        ]
        properties += box(style)
        if style.box == "outline" { properties.append("background.border_color=0x33ffffff") }
        if let colour = style.textColour.flatMap(colour) {
            properties.append("label.color=\(colour)")
        }
        return ["--set", component.id] + properties + fallback(manifest, id: component.id)
    }

    /// Seconds between the clock's own updates while no widget host runs.
    public static let fallbackSeconds = 30

    /// A clock keeps time while the app is not running: SketchyBar runs
    /// `macarchy widget fallback` for it every half minute, which does
    /// nothing while a widget host runs. Other readings keep their last
    /// values until the app opens again, which is less wrong than a clock
    /// that has stopped.
    private func fallback(_ manifest: WidgetManifest, id: String) -> [String] {
        guard manifest.source == "date" else { return ["update_freq=0"] }
        return [
            "script=\(command) widget fallback \(Shell.quote(id))",
            "update_freq=\(Self.fallbackSeconds)"
        ]
    }

    /// An empty gap item, an icon item, a lines item whose icon and label
    /// hold the two lines, right-aligned in a column as wide as the widest
    /// sample, and a box around the icon and lines.
    private func stackedArguments(
        _ component: BarComponent, manifest: WidgetManifest, style: WidgetStyle, icon: [String]
    ) -> [String] {
        // The icon's fixed width is the whole item: the column, then the
        // inset. SketchyBar right-aligns text against the end of its slot,
        // less its right padding, so the top line ends at the column's edge.
        // The label takes no width and starts where the icon's slot ends, so
        // it right-aligns back against the same edge, under the top line.
        // Each item is its own window, so nothing may reach past the icon's
        // slot; negative padding would push the lines out of view.
        let column = Self.columnCharacters(manifest) * Self.characterWidth
        let font = "Menlo:Bold:10.0"
        let right = Int(style.paddingRight ?? inset)
        var lines = [
            "icon.font=\(font)", "label.font=\(font)",
            "icon.width=\(column + right + (style.showIcon == false ? Int(style.paddingLeft ?? inset) : 0))",
            "label.width=0", "icon.align=right", "label.align=right", "icon.y_offset=6",
            "label.y_offset=-5", "icon.padding_left=0", "icon.padding_right=\(right)",
            "label.padding_left=0", "label.padding_right=\(right)", "padding_left=0",
            "padding_right=0", "width=dynamic", "background.drawing=off", "script=",
            icon.first { $0.hasPrefix("click_script=") } ?? ""
        ]
        if let colour = style.textColour.flatMap(colour) {
            lines += ["icon.color=\(colour)", "label.color=\(colour)"]
        }
        let glyph =
            icon + [
                "label.drawing=off", "background.drawing=off", "padding_left=0",
                "padding_right=0", "icon.padding_left=\(Int(style.paddingLeft ?? inset))",
                "icon.padding_right=\(style.showIcon == false ? 0 : Self.spacing)",
                "icon.y_offset=0",
                "width=\(style.showIcon == false ? "0" : "dynamic")"
            ]
        let box =
            [
                "background.height=\(boxHeight)",
                "background.corner_radius=\(Int(style.radius ?? 5))",
                "background.padding_left=0", "background.padding_right=0"
            ]
            + box(style)
            + (style.box == "outline" ? ["background.border_color=0x33ffffff"] : [])
            // SketchyBar may hand a click to the bracket rather than the item
            // under it, so the box clicks the same as the widget's items.
            + [icon.first { $0.hasPrefix("click_script=") } ?? "click_script="]
        let gapProperties = [
            "width=\(gap)", "icon.drawing=off", "label.drawing=off", "background.drawing=off",
            "padding_left=0", "padding_right=0", "script=", "click_script="
        ]
        return ["--set", Self.gapID(component.id)] + gapProperties + ["--set", component.id] + glyph
            + ["--set", Self.linesID(component.id)] + lines + ["--set", Self.boxID(component.id)]
            + box
    }

    private func box(_ style: WidgetStyle) -> [String] {
        var properties: [String]
        switch style.box ?? "none" {
        case "outline":
            properties = [
                "background.drawing=on", "background.color=0x00000000", "background.border_width=1"
            ]
        case "fill":
            properties = [
                "background.drawing=on", "background.color=0x22ffffff", "background.border_width=0"
            ]
        default:
            properties = ["background.drawing=off"]
        }
        if let radius = style.radius {
            properties.append("background.corner_radius=\(Int(radius))")
        }
        return properties
    }

    /// A style colour as SketchyBar takes it. `text` is the bar's default,
    /// so it sets nothing.
    func colour(_ name: String) -> String? {
        switch name {
        case "text": nil
        case "accent": accent
        case "muted": muted
        default: WidgetColour.sketchybar(name)
        }
    }

    private static func points(_ size: Double) -> String {
        size.rounded() == size ? String(Int(size)) : String(size)
    }
}
