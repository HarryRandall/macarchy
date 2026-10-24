import Foundation

/// The `widget.json` at the root of a widget folder.
///
/// A manifest is inert data: what a bar widget shows, how it looks, when it
/// updates and what clicking it does. Built-in widgets ship in the same format
/// as people's own, so anything a built-in does, a person's widget can too.
/// Fields that take a fixed set of values are kept as text and checked by
/// `WidgetManifest.check`, so a typo gets a sentence rather than a decoding error.
public struct WidgetManifest: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public static let fileName = "widget.json"

    /// Readings Macarchy provides itself, for widgets that need no script.
    public static let sources = ["date", "battery", "cpu", "gpu", "memory", "network", "spaces"]
    /// System changes a widget can ask to be updated on, as well as its interval.
    public static let events = [
        "system_woke", "power_source_changed", "timezone_changed", "space_changed",
        "front_app_switched", "display_changed", "windows_changed"
    ]
    /// Needs a widget can declare, shown before it is added. Nothing enforces them.
    public static let permissions = ["network"]

    public var schema: Int
    /// Lower-case letters, numbers and hyphens; the folder has the same name.
    public var id: String
    public var name: String
    public var version: String
    public var author: String?
    public var description: String?
    /// A glyph drawn before the label, such as an SF Symbol character.
    public var icon: String?
    /// A reading from `sources`. A widget has a source or a provider, or neither.
    public var source: String?
    /// A script in the folder. It prints JSON, or plain text to set only the label.
    public var provider: String?
    /// What the bar shows, with readings and settings in braces: `"{load}%"`.
    public var label: String?
    public var settings: [String: WidgetSetting]?
    /// The order `settings` was written in, which the editor follows. Filled
    /// in by `check`, since a dictionary does not keep it.
    public var settingsOrder: [String] = []
    public var style: WidgetStyle?
    public var update: WidgetUpdate?
    public var click: WidgetClick?
    public var samples: WidgetSamples?
    public var permissions: [String]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, id, name, version, author, description, icon, source, provider, label
        case settings, style, update, click, samples, permissions
    }

    public init(id: String, name: String, version: String = "1.0.0") {
        schema = Self.schemaVersion
        self.id = id
        self.name = name
        self.version = version
    }

    /// Whether anything in the widget runs as the person: its provider, or a
    /// command run by a click or a dropdown row. Such widgets carry the Script badge.
    public var isScripted: Bool {
        provider != nil || click?.run != nil
            || (click?.dropdown ?? []).contains { $0.run != nil }
    }

    /// Settings in the order they were written.
    public var orderedSettings: [(key: String, setting: WidgetSetting)] {
        let all = settings ?? [:]
        let written = settingsOrder.filter { all[$0] != nil }
        let rest = all.keys.filter { !written.contains($0) }.sorted()
        return (written + rest).compactMap { key in all[key].map { (key, $0) } }
    }
}

/// One thing a person can change about a widget without touching its files.
/// The editor draws a control for each.
public struct WidgetSetting: Codable, Equatable, Sendable {
    public static let types = ["text", "number", "toggle", "choice", "colour", "format"]

    /// One of `types`.
    public var type: String
    public var label: String
    public var `default`: SettingValue?
    /// The values a `choice` can take.
    public var options: [String]?
    public var min: Double?
    public var max: Double?
    public var step: Double?
    /// Shown after a number, such as `min` or `%`.
    public var unit: String?
    public var hint: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case type, label, `default`, options, min, max, step, unit, hint
    }

    public init(type: String, label: String, default value: SettingValue? = nil) {
        self.type = type
        self.label = label
        self.default = value
    }
}

/// How the widget looks on the bar before anyone changes it.
public struct WidgetStyle: Codable, Equatable, Sendable {
    public static let boxes = ["none", "outline", "fill"]
    /// Colours a style can name instead of a hex value, which follow the theme.
    public static let themeColours = ["text", "accent", "muted"]
    /// The most items a row can draw.
    public static let rowLimit = 16

    public var box: String?
    public var size: Double?
    public var iconColour: String?
    public var textColour: String?
    public var radius: Double?
    public var paddingLeft: Double?
    public var paddingRight: Double?
    /// 2 stacks the label's two lines in a fixed-width box beside the icon,
    /// as CPU load over temperature. The label's lines are split at `\n`.
    public var lines: Int?
    /// Draws a row of up to this many items instead of one, one for each
    /// entry in the output's `items`, as Spaces draws one per Space.
    public var row: Int?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case box, size, iconColour, textColour, radius, paddingLeft, paddingRight, lines, row
    }

    public init() {}

    /// These fields, with any left unset taken from `base`.
    public func over(_ base: WidgetStyle?) -> WidgetStyle {
        guard let base else { return self }
        var merged = self
        merged.box = box ?? base.box
        merged.size = size ?? base.size
        merged.iconColour = iconColour ?? base.iconColour
        merged.textColour = textColour ?? base.textColour
        merged.radius = radius ?? base.radius
        merged.paddingLeft = paddingLeft ?? base.paddingLeft
        merged.paddingRight = paddingRight ?? base.paddingRight
        merged.lines = lines ?? base.lines
        merged.row = row ?? base.row
        return merged
    }
}

/// When the label is worked out again.
public struct WidgetUpdate: Codable, Equatable, Sendable {
    /// An interval such as `2s`, `5m` or `1h`, or `second` and `minute` to
    /// update on the boundary, as a clock does.
    public var every: String?
    /// Names from `WidgetManifest.events`.
    public var events: [String]?

    enum CodingKeys: String, CodingKey, CaseIterable { case every, events }

    public init(every: String? = nil, events: [String]? = nil) {
        self.every = every
        self.events = events
    }

    /// Seconds between updates, or nil for no interval. Boundaries count as their length.
    public var seconds: Int? {
        guard let every else { return nil }
        switch every {
        case "second": return 1
        case "minute": return 60
        default:
            guard let unit = every.last, let count = Int(every.dropLast()) else { return nil }
            switch unit {
            case "s": return count
            case "m": return count * 60
            case "h": return count * 3600
            default: return nil
            }
        }
    }
}

/// What clicking the widget does. At most one of these is set.
public struct WidgetClick: Codable, Equatable, Sendable {
    /// An app name, or a URL such as a System Settings page.
    public var open: String?
    /// A command run through the shell, as the person.
    public var run: String?
    /// Rows of a dropdown drawn under the widget.
    public var dropdown: [WidgetMenuRow]?

    enum CodingKeys: String, CodingKey, CaseIterable { case open, run, dropdown }

    public init(open: String? = nil, run: String? = nil, dropdown: [WidgetMenuRow]? = nil) {
        self.open = open
        self.run = run
        self.dropdown = dropdown
    }
}

/// One row of a widget's dropdown.
public struct WidgetMenuRow: Codable, Equatable, Sendable {
    /// Row types, and which drop-down component draws each:
    /// heading (MenuHeader), text (MenuText), reading, action and link (MenuLink),
    /// toggle, choice (MenuChoice), graph (MenuGraph), cores (MenuCores),
    /// apps (MenuApp) and divider.
    public static let types = [
        "heading", "text", "reading", "action", "toggle", "choice", "graph", "cores", "apps",
        "divider"
    ]

    public var type: String
    public var label: String?
    /// A template for the value shown on the right, or the reading a graph,
    /// cores or apps row draws.
    public var value: String?
    /// A command an action row runs.
    public var run: String?
    /// An app or URL an action row opens.
    public var open: String?
    /// The widget setting a toggle or choice row changes.
    public var setting: String?
    /// The choices a choice row shows when it reflects a reading instead of a setting.
    public var options: [String]?
    /// SF Symbol names, one per option, drawn in round tiles as macOS does
    /// for Energy Mode.
    public var icons: [String]?
    /// For a graph: the reading drawn large in its corner, which makes it a
    /// card. Card graphs one after another sit side by side.
    public var current: String?
    /// For a graph: `accent`, `temperature`, which colours the line and the
    /// fill under it by how hot each moment was, or a hex colour.
    public var colour: String?
    /// For a graph: what its numbers are in, `%` or `°`, which also sets
    /// its scale: 0 to 100 for `%`, 40° to 100° for `°`.
    public var unit: String?

    /// Colours a graph row can take besides a hex value.
    public static let graphColours = ["accent", "temperature"]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case type, label, value, run, open, setting, options, icons, current, colour, unit
    }

    public init(type: String, label: String? = nil, value: String? = nil) {
        self.type = type
        self.label = label
        self.value = value
    }
}

/// Values the editor previews the widget with, beside its live reading.
public struct WidgetSamples: Codable, Equatable, Sendable {
    /// The longest label the widget can show, so its width can be fixed.
    public var widest: String?
    /// What it shows when its reading is missing.
    public var unavailable: String?

    enum CodingKeys: String, CodingKey, CaseIterable { case widest, unavailable }

    public init(widest: String? = nil, unavailable: String? = nil) {
        self.widest = widest
        self.unavailable = unavailable
    }
}
