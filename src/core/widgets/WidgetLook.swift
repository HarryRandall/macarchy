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
    /// How the bar reaches the CLI when a widget is clicked.
    public var command = Paths.cliInShell

    public init(
        manifests: [String: WidgetManifest] = [:], accent: String? = nil, muted: String? = nil
    ) {
        self.manifests = manifests
        self.accent = accent
        self.muted = muted
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
        return WidgetLook(manifests: manifests, accent: theme?.colors.borderActive, muted: muted)
    }

    /// The commands that draw `component`'s widget, or none when the widget
    /// is unknown, in which case the item is left as it is.
    public func arguments(for component: BarComponent) -> [String] {
        guard let widget = component.widget, let manifest = manifests[widget] else { return [] }
        let style = manifest.style ?? WidgetStyle()
        let icon = manifest.icon ?? ""
        let size = style.size ?? 12
        var properties = [
            "icon=\(icon)", "icon.drawing=\(icon.isEmpty ? "off" : "on")",
            "label.font=SF Pro:Semibold:\(Self.points(size))",
            "icon.font=SF Pro:Semibold:\(Self.points(size + 3))", "width=dynamic", "script="
        ]
        if let left = style.paddingLeft {
            properties.append("\(icon.isEmpty ? "label" : "icon").padding_left=\(Int(left))")
        }
        if let right = style.paddingRight { properties.append("label.padding_right=\(Int(right))") }
        switch style.box ?? "none" {
        case "outline":
            properties += [
                "background.drawing=on", "background.color=0x00000000", "background.border_width=1"
            ]
        case "fill":
            properties += [
                "background.drawing=on", "background.color=0x22ffffff", "background.border_width=0"
            ]
        default:
            properties.append("background.drawing=off")
        }
        if let radius = style.radius {
            properties.append("background.corner_radius=\(Int(radius))")
        }
        if let colour = style.textColour.flatMap(colour) {
            properties.append("label.color=\(colour)")
        }
        if let colour = style.iconColour.flatMap(colour) {
            properties.append("icon.color=\(colour)")
        }
        let clicks = manifest.click != nil || component.menu != nil
        properties.append(
            "click_script="
                + (clicks ? "\(command) widget click \(Shell.quote(component.id))" : ""))
        return ["--set", component.id] + properties
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
