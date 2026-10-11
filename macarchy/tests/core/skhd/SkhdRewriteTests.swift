import Foundation
import Testing

@testable import Macarchy

/// Rewriting skhdrc edits a file the person almost certainly wrote by hand, so
/// the rules that keep it intact are worth pinning: the command half is never
/// touched, indentation survives, and a line that is not a binding is refused
/// rather than mangled.
@Suite("SkhdConfig rewriting")
struct SkhdRewriteTests {
    @Test("normalises modifier order so one chord has one spelling")
    func keySpecOrder() {
        #expect(SkhdConfig.keySpec(modifiers: ["cmd", "shift"], key: "h") == "shift + cmd - h")
        #expect(SkhdConfig.keySpec(modifiers: ["shift", "cmd"], key: "h") == "shift + cmd - h")
        #expect(SkhdConfig.keySpec(modifiers: [], key: "play") == "play")
    }

    @Test("rewrites the chord and leaves the command alone")
    func rebindKeepsCommand() {
        let text = "cmd + shift - h : yabai -m window --swap west"
        let updated = SkhdConfig.rebind(text, line: 0, modifiers: ["alt"], key: "j")
        #expect(updated == "alt - j : yabai -m window --swap west")
    }

    /// Commands routinely contain colons — osascript calls and URLs — so only
    /// the first one may be treated as the separator.
    @Test("a command containing colons survives a rebind")
    func rebindWithColonsInCommand() {
        let text = #"cmd - o : open "https://example.com:8080/x" # note: keep"#
        let updated = SkhdConfig.rebind(text, line: 0, modifiers: ["cmd", "alt"], key: "o")
        #expect(updated == #"alt + cmd - o : open "https://example.com:8080/x" # note: keep"#)
    }

    @Test("the per-app arrow form keeps its block intact")
    func rebindArrowForm() {
        let text = "cmd - j -> [\n    \"Firefox\" : echo hi\n]"
        let updated = SkhdConfig.rebind(text, line: 0, modifiers: ["ctrl"], key: "k")
        #expect(updated == "ctrl - k -> [\n    \"Firefox\" : echo hi\n]")
    }

    @Test("indentation is preserved")
    func rebindKeepsIndent() {
        let updated = SkhdConfig.rebind(
            "    cmd - h : echo hi", line: 0, modifiers: ["alt"], key: "h")
        #expect(updated == "    alt - h : echo hi")
    }

    @Test("only the target line changes")
    func rebindTouchesOneLine() {
        let text = "# group\ncmd - a : one\ncmd - b : two"
        let updated = SkhdConfig.rebind(text, line: 2, modifiers: ["alt"], key: "b")
        #expect(updated == "# group\ncmd - a : one\nalt - b : two")
    }

    /// A miscounted index must fail loudly rather than corrupt the file.
    @Test("refuses a line that is not a binding")
    func rebindRefusesNonBinding() {
        #expect(SkhdConfig.rebind("# just a comment", line: 0, modifiers: ["cmd"], key: "h") == nil)
        #expect(SkhdConfig.rebind("cmd - h : echo", line: 9, modifiers: ["cmd"], key: "h") == nil)
    }

    @Test("disabling comments the line out and is not repeatable")
    func disableBinding() {
        let text = "cmd - h : echo hi"
        let disabled = SkhdConfig.disable(text, line: 0)
        #expect(disabled == "# cmd - h : echo hi")
        #expect(SkhdConfig.disable(disabled ?? "", line: 0) == nil)
    }

    /// The whole point: what is written has to parse back to what was meant.
    @Test("a rewritten binding parses back to the new chord")
    func roundTrip() {
        let text = "# Focus window\ncmd + shift - h : yabai -m window --focus west"
        let updated = SkhdConfig.rebind(text, line: 1, modifiers: ["alt", "ctrl"], key: "left")
        let parsed = SkhdConfig.parse(updated ?? "")
        #expect(parsed.count == 1)
        #expect(Set(parsed[0].modifiers) == ["ctrl", "alt"])
        #expect(parsed[0].key == "left")
        #expect(parsed[0].command == "yabai -m window --focus west")
        #expect(parsed[0].section == "Focus window")
    }
}
