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
        let manifests = Dictionary(
            catalogue.read().entries.map { ($0.id, $0.manifest) },
            uniquingKeysWith: { first, _ in first })
        let theme = (try? store.read())?.currentTheme.flatMap {
            Theme.load(from: Paths.themesDirectory.appending(path: $0))
        }
        let text = theme?.colors.sketchybarText
        let muted = text.flatMap {
            $0.count == 10 && $0.hasPrefix("0x") ? "0x99" + $0.dropFirst(4) : nil
        }
        return WidgetLook(
            manifests: manifests, accent: theme?.colors.borderActive, muted: muted, text: text)
    }

    // MARK: - Items

    /// The item a two-line widget writes its lines into, beside its icon.
    public static func linesID(_ id: String) -> String { id + ".lines" }
    /// The bracket that draws a two-line widget's box around both items.
    public static func boxID(_ id: String) -> String { id + ".box" }

    /// Points on each side of a widget, so neighbouring boxes sit twice this apart.
    static let gap = 3
    /// Points between a box's edge and what is inside it.
    static let inset = 8.0
    /// Points between a widget's icon and its text.
    static let spacing = 6
    static let boxHeight = 24

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
    /// needs: one item, or a two-line widget's icon, lines and box.
    public func normalised(_ configuration: BarConfiguration) -> BarConfiguration {
        var result = configuration
        for index in result.components.indices where result.components[index].isWidget {
            let id = result.components[index].id
            let stacked = isStacked(result.components[index])
            result.components[index].members = stacked ? [id, Self.linesID(id)] : [id]
            result.components[index].brackets = stacked ? [Self.boxID(id)] : []
        }
        return result
    }

    /// The commands that draw `component`'s widget, or none when the widget
    /// is unknown, in which case the item is left as it is.
    public func arguments(for component: BarComponent) -> [String] {
        guard let widget = component.widget, let manifest = manifests[widget] else { return [] }
        let style = (component.style ?? WidgetStyle()).over(manifest.style)
        let icon = manifest.icon ?? ""
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
        if isStacked(component) {
            return stackedArguments(component, manifest: manifest, style: style, icon: properties)
        }
        // Every widget is laid out the same, whatever the bar's own defaults
        // say: the same gap between boxes and the same inset inside them.
        let left = Int(style.paddingLeft ?? Self.inset)
        let right = Int(style.paddingRight ?? Self.inset)
        properties += [
            "label.font=SF Pro:Semibold:\(Self.points(size))", "width=dynamic",
            "padding_left=\(Self.gap)", "padding_right=\(Self.gap)",
            "icon.padding_left=\(left)", "icon.padding_right=\(Self.spacing)",
            "label.padding_left=\(icon.isEmpty ? left : 0)", "label.padding_right=\(right)",
            "icon.y_offset=0", "label.y_offset=1",
            "background.height=\(Self.boxHeight)",
            "background.corner_radius=\(Int(style.radius ?? 5))"
        ]
        properties += box(style)
        if style.box == "outline" { properties.append("background.border_color=0x33ffffff") }
        if let colour = style.textColour.flatMap(colour) {
            properties.append("label.color=\(colour)")
        }
        return ["--set", component.id] + properties
    }

    /// An icon item, a lines item whose icon and label hold the two lines,
    /// right-aligned in a column as wide as the widest sample, and a box
    /// around them both, as the bar's stacked readings have always been drawn.
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
        let right = Int(style.paddingRight ?? Self.inset)
        var lines = [
            "icon.font=\(font)", "label.font=\(font)", "icon.width=\(column + right)",
            "label.width=0", "icon.align=right", "label.align=right", "icon.y_offset=6",
            "label.y_offset=-5", "icon.padding_left=0", "icon.padding_right=\(right)",
            "label.padding_left=0", "label.padding_right=\(right)", "padding_left=0",
            "padding_right=\(Self.gap)", "width=dynamic", "background.drawing=off", "script=",
            icon.first { $0.hasPrefix("click_script=") } ?? ""
        ]
        if let colour = style.textColour.flatMap(colour) {
            lines += ["icon.color=\(colour)", "label.color=\(colour)"]
        }
        let glyph =
            icon + [
                "label.drawing=off", "background.drawing=off", "padding_left=\(Self.gap)",
                "padding_right=0", "icon.padding_left=\(Int(style.paddingLeft ?? Self.inset))",
                "icon.padding_right=\(Self.spacing)", "icon.y_offset=0"
            ]
        let box =
            [
                "background.height=\(Self.boxHeight)",
                "background.corner_radius=\(Int(style.radius ?? 5))",
                "background.padding_left=0", "background.padding_right=0"
            ]
            + box(style)
            + (style.box == "outline" ? ["background.border_color=0x33ffffff"] : [])
        return ["--set", component.id] + glyph + ["--set", Self.linesID(component.id)] + lines
            + ["--set", Self.boxID(component.id)] + box
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
