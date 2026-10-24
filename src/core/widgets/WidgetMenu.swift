import Foundation

/// One row of an open dropdown, with its templates filled in, ready to draw.
public struct WidgetMenuItem: Equatable, Sendable, Identifiable {
    public let id: Int
    /// A `WidgetMenuRow.types` name.
    public let type: String
    public let label: String
    public let value: String
    /// Whether a toggle is on.
    public let checked: Bool
    /// A choice's options, and which one is picked.
    public let options: [String]
    /// SF Symbol names for a choice's options, drawn in round tiles.
    public let icons: [String]
    public let selected: String?
    /// False for rows that only show something, and for choices that reflect
    /// a reading rather than a setting.
    public let enabled: Bool
}

/// Builds a widget's dropdown and carries out what picking a row means.
public enum WidgetMenu {
    /// The rows to show: an edited menu first, then rows the provider sent,
    /// then the widget's own. Templates are filled from the latest reading,
    /// the settings and the label.
    public static func items(
        instance: WidgetInstance, component: BarComponent?, output: WidgetOutput?, label: String
    ) -> [WidgetMenuItem] {
        let rows = component?.click?.dropdown ?? output?.rows ?? instance.click?.dropdown ?? []
        let values = instance.settings.mapValues(\.string)
            .merging(output?.values ?? [:]) { $1 }
            .merging(["label": label]) { $1 }
        let declared = instance.manifest.settings ?? [:]
        return rows.enumerated().map { index, row in
            let label = WidgetTemplate.render(row.label ?? "", values: values)
            let value = WidgetTemplate.render(row.value ?? "", values: values)
            let setting = row.setting.flatMap { declared[$0] != nil ? $0 : nil }
            let current = setting.flatMap { instance.settings[$0] }
            switch row.type {
            case "toggle":
                return WidgetMenuItem(
                    id: index, type: row.type, label: label, value: "",
                    checked: current == .bool(true), options: [], icons: [], selected: nil,
                    enabled: setting != nil)
            case "choice":
                let options = setting.flatMap { declared[$0]?.options } ?? row.options ?? []
                return WidgetMenuItem(
                    id: index, type: row.type, label: label, value: value, checked: false,
                    options: options, icons: row.icons ?? [], selected: current?.string ?? value,
                    enabled: setting != nil)
            default:
                return WidgetMenuItem(
                    id: index, type: row.type, label: label, value: value, checked: false,
                    options: [], icons: [], selected: nil,
                    enabled: row.type == "action" && (row.open != nil || row.run != nil))
            }
        }
    }

    /// What picking a row does.
    public enum Effect: Equatable, Sendable {
        /// Close the dropdown and open an app or URL.
        case open(String)
        /// Close the dropdown and run a command as the person.
        case run(String)
        /// Save a new value for one of the widget's settings, and keep the
        /// dropdown open to show it.
        case set(String, SettingValue)
        case nothing
    }

    /// What picking row `index` does. A choice row needs the option picked.
    public static func effect(
        of index: Int, option: String? = nil, instance: WidgetInstance, component: BarComponent?,
        output: WidgetOutput?
    ) -> Effect {
        let rows = component?.click?.dropdown ?? output?.rows ?? instance.click?.dropdown ?? []
        guard rows.indices.contains(index) else { return .nothing }
        let row = rows[index]
        let declared = instance.manifest.settings ?? [:]
        switch row.type {
        case "action":
            if let target = row.open { return .open(target) }
            if let command = row.run { return .run(command) }
        case "toggle":
            if let setting = row.setting, declared[setting]?.type == "toggle" {
                return .set(setting, .bool(instance.settings[setting] != .bool(true)))
            }
        case "choice":
            if let setting = row.setting, let option,
                declared[setting]?.options?.contains(option) == true
            {
                return .set(setting, .text(option))
            }
        default: break
        }
        return .nothing
    }

    /// Saves one setting of a widget on the bar, leaving everything else in
    /// `settings.json` as it is.
    public static func save(
        _ key: String, _ value: SettingValue, instance id: String,
        store: SettingsStore = SettingsStore()
    ) throws {
        try store.update { settings in
            guard var configuration = settings.barConfiguration,
                let index = configuration.components.firstIndex(where: { $0.id == id })
            else { throw ConfigurationError("There is no widget called \(id) on the bar") }
            configuration.components[index].settings =
                (configuration.components[index].settings ?? [:])
                .merging([key: value]) { $1 }
            try configuration.validate()
            settings.barConfiguration = configuration
        }
    }
}
