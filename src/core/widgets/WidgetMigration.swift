import Foundation

/// Moves a bar saved before widgets onto them.
///
/// The bar's own Spaces, network, memory, GPU, CPU, battery and clock items
/// become instances of the built-in widgets, keeping their place and colours,
/// whether Macarchy's earlier bar or a person's own made them. Command items
/// become widgets of their own in `Paths.widgetsDirectory`, whose provider
/// runs the same command, so there is one way to run a script and it carries
/// the Script badge. Text items, spacers and items without a widget stay as
/// they are; `moveBar` decides what happens to those.
public enum WidgetMigration {
    /// Native bar items and the built-in widget that replaces each. `ram`
    /// and `network` are the names the owner's own bar used.
    public static let replacements = [
        "workspaces": "spaces", "network": "network", "memory": "memory", "ram": "memory",
        "gpu": "gpu", "cpu": "cpu", "battery": "battery", "calendar": "clock"
    ]

    /// A widget folder the migration needs written before the bar can use it.
    public struct NewWidget: Equatable, Sendable {
        public let manifest: WidgetManifest
        /// The text of `provider.sh`.
        public let provider: String
    }

    public struct Result: Equatable, Sendable {
        public var configuration: BarConfiguration
        public var newWidgets: [NewWidget]
    }

    public static func migrate(
        _ configuration: BarConfiguration, catalogue: WidgetCatalogue = WidgetCatalogue()
    ) -> Result {
        migrate(configuration, taken: catalogue.takenIDs())
    }

    /// The migration itself, given the widget ids already in use.
    static func migrate(_ configuration: BarConfiguration, taken: Set<String>) -> Result {
        var result = configuration
        var newWidgets: [NewWidget] = []
        var widgetIDs = taken
        var componentIDs = Set(configuration.components.map(\.id))
        result.components = configuration.components.map { component in
            if component.isWidget { return component }
            if component.kind == nil, let widget = replacements[component.id] {
                let id = WidgetCatalogue.unusedID(from: "macarchy.\(widget)", taken: componentIDs)
                componentIDs.insert(id)
                return instance(of: widget, replacing: component, id: id)
            }
            if component.kind == "command", let command = component.command {
                let id = WidgetCatalogue.unusedID(from: widgetID(for: component), taken: widgetIDs)
                widgetIDs.insert(id)
                newWidgets.append(widget(id: id, from: component, command: command))
                var converted = component
                converted.kind = nil
                converted.command = nil
                converted.interval = nil
                converted.text = ""
                converted.widget = id
                converted.members = [component.id]
                return converted
            }
            return component
        }
        return Result(configuration: result, newWidgets: newWidgets)
    }

    /// Writes the folders a migration made. Refuses to replace a folder that
    /// is already there, and checks each one reads back as a working widget.
    public static func write(_ widgets: [NewWidget], to root: URL = Paths.widgetsDirectory) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        for widget in widgets {
            let folder = root.appending(path: widget.manifest.id)
            guard !fm.fileExists(atPath: folder.path) else {
                throw ConfigurationError(
                    "A widget folder called \(widget.manifest.id) already exists")
            }
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: false)
                try encoder.encode(widget.manifest).write(
                    to: folder.appending(path: WidgetManifest.fileName), options: .atomic)
                let provider = folder.appending(path: "provider.sh")
                try Data(widget.provider.utf8).write(to: provider, options: .atomic)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: provider.path)
                let check = WidgetManifest.check(folder: folder)
                guard check.ok else {
                    throw ConfigurationError(
                        check.problems.map(\.description).joined(separator: "\n"))
                }
            } catch {
                try? fm.removeItem(at: folder)
                throw error
            }
        }
    }

    private static func instance(
        of widget: String, replacing component: BarComponent, id: String
    ) -> BarComponent {
        var instance = BarComponent(
            id: id, title: component.title, side: component.side, members: [id],
            visible: component.visible)
        instance.widget = widget
        instance.colour = component.colour
        instance.iconColour = component.iconColour
        instance.backgroundColour = component.backgroundColour
        instance.cornerRadius = component.cornerRadius
        instance.paddingOverride = component.paddingOverride
        instance.spacingOverride = component.spacingOverride
        return instance
    }

    /// A widget id from a command item's id, such as `uptime` from `macarchy.uptime`.
    static func widgetID(for component: BarComponent) -> String {
        let stem =
            component.id.hasPrefix("macarchy.")
            ? String(component.id.dropFirst("macarchy.".count)) : component.id
        let cleaned = stem.lowercased().map { character -> Character in
            character.isASCII && (character.isLetter || character.isNumber) ? character : "-"
        }
        let id = String(cleaned).split(separator: "-").joined(separator: "-")
        return id.isEmpty ? "command" : String(id.prefix(37))
    }

    private static func widget(
        id: String, from component: BarComponent, command: String
    )
        -> NewWidget
    {
        let title = component.title.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        var manifest = WidgetManifest(
            id: id, name: title.isEmpty ? "Command" : String(title.prefix(40)))
        manifest.description = "Made from the command item \"\(manifest.name)\"."
        manifest.icon = component.icon.isEmpty ? nil : component.icon
        manifest.provider = "provider.sh"
        let interval = min(max(component.interval ?? 30, 1), 86_400)
        manifest.update = WidgetUpdate(every: "\(interval)s")
        let provider = """
            #!/bin/sh
            # Made by Macarchy from the command item "\(manifest.name)".
            # Whatever this prints becomes the widget's label.
            \(command)

            """
        return NewWidget(manifest: manifest, provider: provider)
    }
}
