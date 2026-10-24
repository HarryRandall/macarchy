import Macarchy

// Mirrors `bridge/contract/shortcuts.ts`.
struct ShortcutsState: Codable, Sendable {
    var revision: String
    var bindings: [Binding]
    /// The desktops that exist now, or `nil` when yabai cannot say.
    var desktops: Int?

    struct Binding: Codable, Sendable {
        var id: Int
        var modifiers: [String]
        var key: String
        var caps: [String]
        var command: String
        var section: String?
        var passthrough: Bool
        var appOverrides: [Override]

        struct Override: Codable, Sendable {
            var app: String
            var command: String
        }

        enum CodingKeys: CodingKey {
            case id, modifiers, key, caps, command, section, passthrough, appOverrides
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(modifiers, forKey: .modifiers)
            try container.encode(key, forKey: .key)
            try container.encode(caps, forKey: .caps)
            try container.encode(command, forKey: .command)
            try container.encode(section, forKey: .section)
            try container.encode(passthrough, forKey: .passthrough)
            try container.encode(appOverrides, forKey: .appOverrides)
        }
    }

    enum CodingKeys: CodingKey { case revision, bindings, desktops }

    /// `nil` is sent as `null`, so the page can tell "unknown" from a missing field.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(revision, forKey: .revision)
        try container.encode(bindings, forKey: .bindings)
        try container.encode(desktops, forKey: .desktops)
    }

    init(_ snapshot: ShortcutsSnapshot, desktops: Int?) {
        revision = snapshot.revision
        self.desktops = desktops
        bindings = snapshot.bindings.map { binding in
            Binding(
                id: binding.id, modifiers: binding.modifiers, key: binding.key,
                caps: binding.keyCaps,
                command: binding.command, section: binding.section,
                passthrough: binding.passthrough,
                appOverrides: binding.appOverrides.map { .init(app: $0.app, command: $0.command) })
        }
    }
}

struct ShortcutEditParams: Decodable {
    var id: Int
    var revision: String
    var chord: ShortcutChord
}
struct ShortcutDisableParams: Decodable {
    var id: Int
    var revision: String
}
struct ShortcutResetParams: Decodable { var revision: String }
struct ShortcutValidateParams: Decodable {
    var id: Int
    var chord: ShortcutChord
}
struct ShortcutValidation: Codable {
    var spec: String
    var caps: [String]
    var conflicts: [Int]
}
struct ShortcutMutation: Codable {
    var state: ShortcutsState
    var warning: String
}

extension BridgeEvent {
    static func shortcutsChanged(_ state: ShortcutsState) -> BridgeEvent {
        BridgeEvent("shortcuts.changed", state: state)
    }
    static func shortcutsUnavailable(_ message: String) -> BridgeEvent {
        BridgeEvent("shortcuts.unavailable", state: message)
    }
}
