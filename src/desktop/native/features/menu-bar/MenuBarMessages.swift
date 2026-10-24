import Foundation
import Macarchy

// Mirrors `src/desktop/ui/src/bridge/contract/menu-bar.ts`.

/// One component of the bar as the Menu Bar page lists it. `zone` is spelt
/// `centre` here and `center` in SketchyBar.
struct MenuBarItemState: Codable, Sendable, Equatable {
    var id: String
    var title: String
    var zone: String
    var visible: Bool
    /// `text`, `spacer` or `command` for items made on the page; null for
    /// the bar's own.
    var kind: String?
    var text: String
    var icon: String
    var command: String?
    var interval: Int?
    /// The widget a `widget` item shows, and its edits to that widget.
    var widget: String?
    var settings: [String: SettingValue]
    var style: WidgetStyle?
    var click: WidgetClick?
    /// What the item shows on the bar now, for the preview.
    var reading: String
}

/// An item as the page sends it back: everything but the reading.
struct MenuBarItemEdit: Codable, Sendable, Equatable {
    var id: String
    var title: String
    var zone: String
    var visible: Bool
    var kind: String?
    var text: String
    var icon: String
    var command: String?
    var interval: Int?
    var widget: String?
    var settings: [String: SettingValue]
    var style: WidgetStyle?
    var click: WidgetClick?
}

struct MenuBarSettings: Codable, Sendable, Equatable {
    var height: Int
    var position: String
    var padding: Int
}

struct MenuBarState: Codable, Sendable, Equatable {
    var items: [MenuBarItemState]
    var bar: MenuBarSettings
    /// Every widget that can go on the bar, built-in and the person's own.
    var widgets: [WidgetInfo]
    /// Widget folders that could not be read, so the page can say why.
    var widgetProblems: [WidgetFolderProblems]
    /// Why the bar could not be read, such as SketchyBar not running.
    var unavailableReason: String?
}

struct MenuBarApplyParams: Codable, Sendable {
    var items: [MenuBarItemEdit]
    var bar: MenuBarSettings
}

/// A widget as the page's library and editor show it. Fields the manifest
/// leaves out are left out here too.
struct WidgetInfo: Codable, Sendable, Equatable {
    var id: String
    var name: String
    var description: String?
    var author: String?
    var version: String
    var icon: String?
    /// `builtIn` or `user`.
    var origin: String
    /// Whether anything in it runs a command as the person.
    var scripted: Bool
    /// The widget's folder, with the home folder written as `~`.
    var folder: String
    /// The files in the folder, by name.
    var files: [String]
    /// `widget.json` as written.
    var manifest: String
    var label: String?
    var source: String?
    var provider: String?
    var settings: [WidgetSettingInfo]
    var style: WidgetStyle?
    var click: WidgetClick?
    var update: WidgetUpdate?
    var samples: WidgetSamples?
}

/// A widget folder that could not be used, by folder name, with what is wrong.
struct WidgetFolderProblems: Codable, Sendable, Equatable {
    var folder: String
    /// Each with its line in `widget.json` when there is one.
    var problems: [String]
}

/// One of a widget's settings, with its name, in the order written.
struct WidgetSettingInfo: Codable, Sendable, Equatable {
    var key: String
    var type: String
    var label: String
    var `default`: SettingValue?
    var options: [String]?
    var min: Double?
    var max: Double?
    var step: Double?
    var unit: String?
    var hint: String?
}

struct WidgetParams: Codable, Sendable {
    var widget: String
}

struct WidgetFolderParams: Codable, Sendable {
    /// Null for the folder that holds the person's widgets.
    var widget: String?

    private enum CodingKeys: String, CodingKey { case widget }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widget, forKey: .widget)
    }
}

struct WidgetFileParams: Codable, Sendable {
    var widget: String
    var file: String
}

struct WidgetDuplicateResult: Codable, Sendable, Equatable {
    var state: MenuBarState
    /// The copy's id.
    var widget: String
}

// Synthesised encoding leaves nil optionals out; the contract declares them as
// `T | null`, so these spell them out.

extension MenuBarItemState {
    private enum CodingKeys: String, CodingKey {
        case id, title, zone, visible, kind, text, icon, command, interval, widget, settings
        case style, click, reading
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(zone, forKey: .zone)
        try container.encode(visible, forKey: .visible)
        try container.encode(kind, forKey: .kind)
        try container.encode(text, forKey: .text)
        try container.encode(icon, forKey: .icon)
        try container.encode(command, forKey: .command)
        try container.encode(interval, forKey: .interval)
        try container.encode(widget, forKey: .widget)
        try container.encode(settings, forKey: .settings)
        try container.encode(style, forKey: .style)
        try container.encode(click, forKey: .click)
        try container.encode(reading, forKey: .reading)
    }
}

extension MenuBarItemEdit {
    private enum CodingKeys: String, CodingKey {
        case id, title, zone, visible, kind, text, icon, command, interval, widget, settings
        case style, click
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(zone, forKey: .zone)
        try container.encode(visible, forKey: .visible)
        try container.encode(kind, forKey: .kind)
        try container.encode(text, forKey: .text)
        try container.encode(icon, forKey: .icon)
        try container.encode(command, forKey: .command)
        try container.encode(interval, forKey: .interval)
        try container.encode(widget, forKey: .widget)
        try container.encode(settings, forKey: .settings)
        try container.encode(style, forKey: .style)
        try container.encode(click, forKey: .click)
    }
}

extension MenuBarState {
    private enum CodingKeys: String, CodingKey {
        case items, bar, widgets, widgetProblems, unavailableReason
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(bar, forKey: .bar)
        try container.encode(widgets, forKey: .widgets)
        try container.encode(widgetProblems, forKey: .widgetProblems)
        try container.encode(unavailableReason, forKey: .unavailableReason)
    }
}
