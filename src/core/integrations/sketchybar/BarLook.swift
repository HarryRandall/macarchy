import Foundation

/// The bar itself, under its widgets: geometry, the theme's bar and text
/// colours, and the font the Spaces widget draws apps with. Startup sets it
/// up before adding the widgets, and a theme change recolours it in place.
public enum BarLook {
    /// The colours a theme gives the bar, or Macarchy's defaults with no
    /// theme. The bar is one step above transparent by default: a fully
    /// transparent bar is treated as pass-through by the compositor, which
    /// leaves stale pixels where items relayout.
    public struct Colours: Equatable, Sendable {
        public var bar = "0x01000000"
        public var text = "0xffffffff"
        public init() {}

        public init(_ outputs: ThemeOutputs) {
            bar = outputs.barBackground
            text = outputs.barText
        }

        /// The colours of the installed theme called `name`. A theme that
        /// cannot be read, or one without a Ghostty palette, falls back to
        /// the defaults rather than stopping the bar from starting.
        public static func theme(_ name: String?) -> Colours {
            guard let name else { return Colours() }
            let directory = Paths.themesDirectory.appending(path: name)
            guard let theme = Theme.load(from: directory) else { return Colours() }
            let palette = try? theme.palette(in: directory)
            return Colours(ThemeOutputs(theme: theme, ghostty: palette ?? ""))
        }
    }

    /// sketchybar-app-font, through the app link so an updated app keeps
    /// working, or from this copy's resources before setup has linked it.
    public static var font: URL? {
        let name = "sketchybar/sketchybar-app-font.ttf"
        return [Paths.appLink.appending(path: "Contents/Resources"), Paths.resources]
            .compactMap { $0?.appending(path: name) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Sets up the bar: geometry from the menu bar settings, falling back to
    /// Macarchy's, the theme's colours, and the defaults every item starts
    /// from. Widgets set everything else themselves.
    public static func arguments(
        values: [String: String], colours: Colours, font: URL? = BarLook.font
    ) -> [String] {
        ["--bar"]
            + StartupConfiguration.sketchybarKeys.map {
                "\($0.key)=\(values[$0.env] ?? $0.fallback)"
            }
            + ["color=\(colours.bar)"]
            + (font.map { ["--load-font", $0.path] } ?? [])
            + ["--default", "icon.color=\(colours.text)", "label.color=\(colours.text)"]
    }

    /// Repaints a running bar in new colours without rebuilding it: the bar,
    /// the defaults, and the text of every widget item on the bar now.
    /// `BarCommands.replay` then puts back each widget's own colours.
    public static func recolour(
        _ configuration: BarConfiguration, colours: Colours, existing: Set<String>
    ) -> [String] {
        var arguments = [
            "--bar", "color=\(colours.bar)",
            "--default", "icon.color=\(colours.text)", "label.color=\(colours.text)"
        ]
        for component in configuration.components where component.isWidget {
            for item in component.members where existing.contains(item) {
                arguments += [
                    "--set", item, "icon.color=\(colours.text)", "label.color=\(colours.text)"
                ]
            }
        }
        return arguments
    }
}
