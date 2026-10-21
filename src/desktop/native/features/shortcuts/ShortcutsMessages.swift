import Macarchy

// Mirrors `bridge/contract/shortcuts.ts`.
struct ShortcutsState: Encodable, Sendable {
    var revision: String
    var bindings: [Binding]

    struct Binding: Encodable, Sendable {
        var id: Int
        var modifiers: [String]
        var key: String
        var caps: [String]
        var command: String
        var section: String?
        var passthrough: Bool
        var appOverrides: [Override]

        struct Override: Encodable, Sendable {
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

    init(_ snapshot: ShortcutsSnapshot) {
        revision = snapshot.revision
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
struct ShortcutValidation: Encodable {
    var spec: String
    var caps: [String]
    var conflicts: [Int]
}
struct ShortcutMutation: Encodable {
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
