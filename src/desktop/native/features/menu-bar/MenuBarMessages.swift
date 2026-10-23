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
}

struct MenuBarSettings: Codable, Sendable, Equatable {
    var height: Int
    var position: String
    var padding: Int
}

struct MenuBarState: Codable, Sendable, Equatable {
    var items: [MenuBarItemState]
    var bar: MenuBarSettings
    /// Why the bar could not be read, such as SketchyBar not running.
    var unavailableReason: String?
}

struct MenuBarApplyParams: Codable, Sendable {
    var items: [MenuBarItemEdit]
    var bar: MenuBarSettings
}

// Synthesised encoding leaves nil optionals out; the contract declares them as
// `T | null`, so these spell them out.

extension MenuBarItemState {
    private enum CodingKeys: String, CodingKey {
        case id, title, zone, visible, kind, text, icon, command, interval, reading
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
        try container.encode(reading, forKey: .reading)
    }
}

extension MenuBarItemEdit {
    private enum CodingKeys: String, CodingKey {
        case id, title, zone, visible, kind, text, icon, command, interval
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
    }
}

extension MenuBarState {
    private enum CodingKeys: String, CodingKey { case items, bar, unavailableReason }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(bar, forKey: .bar)
        try container.encode(unavailableReason, forKey: .unavailableReason)
    }
}
