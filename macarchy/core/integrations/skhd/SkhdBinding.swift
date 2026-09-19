import Foundation

/// One parsed skhdrc binding, plus how it is spelled on screen.
public struct SkhdBinding: Identifiable, Sendable, Hashable {
    public let id: Int  // source line, which is also a stable identity
    public let modifiers: [String]
    public let key: String
    public let command: String
    public let section: String?
    /// The `->` form, where skhd also forwards the key to the focused app.
    public let passthrough: Bool
    /// The `[ "App" : cmd … ]` form: one binding behaving differently per app.
    public let appOverrides: [AppOverride]

    public struct AppOverride: Sendable, Hashable {
        public let app: String  // "*" is the fallback
        public let command: String
    }

    /// Display form, e.g. ["⌘", "⇧", "H"].
    public var keyCaps: [String] {
        modifiers.map(Self.symbol(forModifier:)) + [Self.display(key: key)]
    }

    public static func symbol(forModifier modifier: String) -> String {
        switch modifier.lowercased() {
        case "cmd", "lcmd", "rcmd": "⌘"
        case "shift", "lshift", "rshift": "⇧"
        case "alt", "lalt", "ralt", "opt": "⌥"
        case "ctrl", "lctrl", "rctrl": "⌃"
        case "fn": "fn"
        case "hyper": "✦"
        default: modifier
        }
    }

    /// skhd accepts raw keycodes; a table of the ones in use beats showing 0x18.
    public static let keycodeNames: [String: String] = [
        "0x18": "=", "0x1B": "-", "0x21": "[", "0x1E": "]",
        "0x29": ";", "0x27": "'", "0x2B": ",", "0x2F": ".", "0x2C": "/",
        "0x32": "`", "0x2A": "\\"
    ]

    public static func display(key: String) -> String {
        if let named = keycodeNames[key.uppercased().replacingOccurrences(of: "0X", with: "0x")] {
            return named
        }
        switch key.lowercased() {
        case "return": return "↩"
        case "space": return "space"
        case "left": return "←"
        case "right": return "→"
        case "up": return "↑"
        case "down": return "↓"
        case "tab": return "⇥"
        case "escape": return "⎋"
        case "delete": return "⌫"
        default: return key.count == 1 ? key.uppercased() : key
        }
    }
}
