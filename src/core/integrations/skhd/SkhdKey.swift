import Foundation

/// How skhd spells a key.
///
/// skhd reads a single letter or digit through the current keyboard layout,
/// knows a fixed set of key names, and needs a hex keycode for everything
/// else: `-`, `:`, `;` and most other punctuation are part of its own syntax.
public enum SkhdKey {
    /// skhd's key names and their virtual keycodes. skhd calls Backspace
    /// `backspace` and forward delete `delete`.
    public static let named: [String: UInt16] = [
        "return": 0x24, "tab": 0x30, "space": 0x31, "backspace": 0x33, "escape": 0x35,
        "delete": 0x75, "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
        "insert": 0x72, "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61, "f7": 0x62,
        "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F, "f13": 0x69,
        "f14": 0x6B, "f15": 0x71, "f16": 0x6A, "f17": 0x40, "f18": 0x4F, "f19": 0x50,
        "f20": 0x5A
    ]

    private static let names = Dictionary(uniqueKeysWithValues: named.map { ($1, $0) })

    /// Keypad keys type the same characters as the main keys, which skhd would
    /// map back to the main keys, so they are always written as keycodes.
    public static let keypad: [UInt16: String] = [
        0x41: "Keypad .", 0x43: "Keypad *", 0x45: "Keypad +", 0x47: "Clear",
        0x4B: "Keypad /", 0x4C: "Enter", 0x4E: "Keypad -", 0x51: "Keypad =",
        0x52: "Keypad 0", 0x53: "Keypad 1", 0x54: "Keypad 2", 0x55: "Keypad 3",
        0x56: "Keypad 4", 0x57: "Keypad 5", 0x58: "Keypad 6", 0x59: "Keypad 7",
        0x5B: "Keypad 8", 0x5C: "Keypad 9"
    ]

    /// The spelling to write for a pressed key.
    ///
    /// `character` is what the key types with no modifiers held, Shift
    /// included, so Shift+1 records `1` rather than `!`.
    public static func spelling(keyCode: UInt16, character: String?) -> String {
        if let name = names[keyCode] { return name }
        if keypad[keyCode] == nil, let character, character.count == 1,
            let first = character.lowercased().first, first.isASCII,
            first.isLetter || first.isNumber
        {
            return String(first)
        }
        return hex(keyCode)
    }

    public static func hex(_ code: UInt16) -> String { String(format: "0x%02X", code) }

    /// The spelling to write for a key named by the interface or found in a
    /// file: skhd's name where it has one, a letter or digit as itself, and a
    /// hex keycode for punctuation, keypad keys and everything else.
    public static func spelling(_ key: String) -> String {
        let lower = key.lowercased()
        if lower.hasPrefix("0x"), let code = UInt16(lower.dropFirst(2), radix: 16) {
            return names[code] ?? hex(code)
        }
        if let code = SkhdBinding.keycodeNames.first(where: { $0.value == key })?.key {
            return spelling(code)
        }
        return lower
    }

    /// What the main keys type on a US layout. skhd reads a letter or digit
    /// through the current layout, so a raw keycode is compared as the key it
    /// most often is, and `cmd - 0x28` still clashes with `cmd - k`.
    static let usLayout: [UInt16: String] = [
        0x00: "a", 0x01: "s", 0x02: "d", 0x03: "f", 0x04: "h", 0x05: "g", 0x06: "z", 0x07: "x",
        0x08: "c", 0x09: "v", 0x0B: "b", 0x0C: "q", 0x0D: "w", 0x0E: "e", 0x0F: "r",
        0x10: "y", 0x11: "t", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6",
        0x17: "5", 0x18: "=", 0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
        0x1E: "]", 0x1F: "o", 0x20: "u", 0x21: "[", 0x22: "i", 0x23: "p", 0x25: "l",
        0x26: "j", 0x27: "'", 0x28: "k", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
        0x2D: "n", 0x2E: "m", 0x2F: ".", 0x32: "`"
    ]

    /// One spelling per key, so `=` and `0x18`, or `0x24` and `return`,
    /// compare equal when looking for a chord that is already taken.
    public static func normalised(_ key: String) -> String {
        let spelt = spelling(key)
        if spelt.hasPrefix("0x"), let code = UInt16(spelt.dropFirst(2), radix: 16),
            let typed = usLayout[code]
        {
            return typed
        }
        return spelt
    }

    /// Modifiers as sets of plain names. A side-specific modifier overlaps the
    /// plain one, and `hyper` and `meh` expand, so any overlap counts as taken.
    public static func normalised(modifiers: some Sequence<String>) -> Set<String> {
        var result: Set<String> = []
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "hyper": result.formUnion(["cmd", "alt", "shift", "ctrl"])
            case "meh": result.formUnion(["alt", "shift", "ctrl"])
            case "lcmd", "rcmd": result.insert("cmd")
            case "lalt", "ralt", "opt": result.insert("alt")
            case "lshift", "rshift": result.insert("shift")
            case "lctrl", "rctrl": result.insert("ctrl")
            case let other: result.insert(other)
            }
        }
        return result
    }
}
