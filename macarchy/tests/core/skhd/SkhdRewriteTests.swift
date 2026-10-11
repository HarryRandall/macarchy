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

    @Test("an arrow inside a command is not mistaken for passthrough")
    func arrowInsideCommand() {
        let text = #"cmd - a : echo "a -> b""#
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.count == 1)
        #expect(parsed[0].passthrough == false)
        #expect(parsed[0].command == #"echo "a -> b""#)
        let updated = SkhdConfig.rebind(text, line: 0, modifiers: ["alt"], key: "a")
        #expect(updated == #"alt - a : echo "a -> b""#)
    }

    @Test("passthrough survives a rebind of the colon form")
    func passthroughColonForm() {
        let text = "cmd - q -> : open -a Finder"
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.first?.passthrough == true)
        #expect(
            SkhdConfig.rebind(text, line: 0, modifiers: ["ctrl"], key: "q")
                == "ctrl - q -> : open -a Finder")
    }

    @Test("a per-app block without an arrow is parsed")
    func blockWithoutArrow() {
        let text = "cmd - w [\n    \"Messages\" : echo quit\n    * : echo close\n]"
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.count == 1)
        #expect(parsed[0].endLine == 3)
        #expect(parsed[0].appOverrides.count == 2)
        #expect(parsed[0].passthrough == false)
    }

    @Test("disabling a per-app block comments out its body and bracket")
    func disableBlock() throws {
        let text = "cmd - w -> [\n    \"Messages\" : echo quit\n]\ncmd - h : echo hi"
        let binding = try #require(SkhdConfig.parse(text).first)
        let disabled = try #require(SkhdConfig.disable(text, binding: binding))
        #expect(
            disabled
                == "# cmd - w -> [\n#     \"Messages\" : echo quit\n# ]\ncmd - h : echo hi")
        let remaining = SkhdConfig.parse(disabled)
        #expect(remaining.map(\.key) == ["h"])
    }

    @Test("edits refuse a file that changed since it was read")
    func staleEditsAreRefused() throws {
        let text = "cmd - a : one\ncmd - b : two"
        let binding = try #require(SkhdConfig.parse(text).last)
        let edited = "# inserted\n" + text
        #expect(SkhdConfig.rebind(edited, binding: binding, modifiers: ["alt"], key: "b") == nil)
        #expect(SkhdConfig.disable(edited, binding: binding) == nil)
        #expect(
            SkhdConfig.rebind(text, binding: binding, modifiers: ["alt"], key: "b")
                == "cmd - a : one\nalt - b : two")
    }

    @Test("an unterminated block is not offered for editing")
    func unterminatedBlock() {
        #expect(SkhdConfig.parse("cmd - w [\n    * : echo").isEmpty)
    }
}
