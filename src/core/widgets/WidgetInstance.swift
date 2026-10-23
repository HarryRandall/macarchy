import Foundation

/// A widget placed on the bar: the component that shows it, joined with its
/// manifest and the settings it runs with.
public struct WidgetInstance: Equatable, Sendable {
    /// The SketchyBar item, which is the component's id.
    public let id: String
    public let manifest: WidgetManifest
    public let directory: URL
    /// The manifest's defaults with the component's saved values over them.
    public let settings: [String: SettingValue]
    public let visible: Bool

    /// Every widget component that can run, and why each of the others cannot.
    public static func resolve(
        _ configuration: BarConfiguration?, catalogue: WidgetCatalogue.Snapshot
    ) -> (instances: [WidgetInstance], problems: [String: String]) {
        var instances: [WidgetInstance] = []
        var problems: [String: String] = [:]
        for component in configuration?.components ?? [] {
            guard let widget = component.widget else { continue }
            guard let entry = catalogue.entry(widget) else {
                problems[component.id] = "There is no widget called \(widget)"
                continue
            }
            var settings: [String: SettingValue] = [:]
            for (key, setting) in entry.manifest.settings ?? [:] {
                if let value = setting.default { settings[key] = value }
            }
            // A saved value the widget no longer accepts falls back to its default.
            let declared = entry.manifest.settings ?? [:]
            for (key, value) in component.settings ?? [:] {
                if let setting = declared[key], setting.mismatch(value) == nil {
                    settings[key] = value
                }
            }
            instances.append(
                WidgetInstance(
                    id: component.id, manifest: entry.manifest, directory: entry.directory,
                    settings: settings, visible: component.visible))
        }
        return (instances, problems)
    }
}
