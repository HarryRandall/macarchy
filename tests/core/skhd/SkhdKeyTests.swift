import Testing
@testable import Macarchy

struct SkhdKeyTests {
    @Test("letters and digits are written as characters skhd reads through the layout")
    func lettersAndDigits() {
        #expect(SkhdKey.spelling(keyCode: 0x04, character: "H") == "h")
        #expect(SkhdKey.spelling(keyCode: 0x12, character: "1") == "1")
    }

    @Test("punctuation is written as a keycode, never as skhd syntax")
    func punctuation() {
        #expect(SkhdKey.spelling(keyCode: 0x1B, character: "-") == "0x1B")
        #expect(SkhdKey.spelling(keyCode: 0x18, character: "=") == "0x18")
        #expect(SkhdKey.spelling(keyCode: 0x29, character: ";") == "0x29")
        #expect(SkhdKey.spelling(keyCode: 0x2F, character: ".") == "0x2F")
    }

    @Test("Backspace and forward delete use skhd's names")
    func deleteKeys() {
        #expect(SkhdKey.spelling(keyCode: 0x33, character: "\u{7F}") == "backspace")
        #expect(SkhdKey.spelling(keyCode: 0x75, character: "\u{F728}") == "delete")
        #expect(SkhdKey.spelling(keyCode: 0x24, character: "\r") == "return")
    }

    @Test("keypad keys are keycodes so they stay distinct from the main keys")
    func keypad() {
        #expect(SkhdKey.spelling(keyCode: 0x53, character: "1") == "0x53")
        #expect(SkhdBinding.display(key: "0x53") == "Keypad 1")
    }

    @Test("written spellings parse back into the same binding")
    func roundTrip() {
        let spec = SkhdConfig.keySpec(
            modifiers: ["ctrl", "alt"], key: SkhdKey.spelling(keyCode: 0x1B, character: "-"))
        let parsed = SkhdConfig.parse("\(spec) : echo smaller\n")
        #expect(parsed.first?.key == "0x1B")
        #expect(parsed.first?.modifiers == ["ctrl", "alt"])
    }

    @Test("equivalent spellings compare equal")
    func normalising() {
        #expect(SkhdKey.normalised("=") == SkhdKey.normalised("0x18"))
        #expect(SkhdKey.normalised("0x18") == SkhdKey.normalised("0X18"))
        #expect(SkhdKey.normalised("0x24") == "return")
        #expect(SkhdKey.normalised("H") == "h")
        #expect(
            SkhdKey.normalised(modifiers: ["hyper"])
                == SkhdKey.normalised(modifiers: ["cmd", "alt", "shift", "ctrl"]))
        #expect(SkhdKey.normalised(modifiers: ["lcmd"]) == ["cmd"])
    }
}
