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

    /// skhd escapes the line break after a trailing backslash, so the next
    /// line belongs to the command. Commenting out only the first line left the
    /// rest live, and skhd then rejected the whole file.
    @Test("a continued command is one shortcut and is disabled whole")
    func continuedCommand() throws {
        let first = "cmd - x : yabai -m window --focus west \\"
        let second = #"  || osascript -e 'display notification "a: b"'"#
        let text = [first, second, "cmd - h : echo hi"].joined(separator: "\n")
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.map(\.key) == ["x", "h"])
        let binding = try #require(parsed.first)
        #expect(binding.endLine == 1)
        #expect(
            binding.command
                == #"yabai -m window --focus west   || osascript -e 'display notification "a: b"'"#)

        let disabled = try #require(SkhdConfig.disable(text, binding: binding))
        #expect(
            disabled == ["# " + first, "# " + second, "cmd - h : echo hi"].joined(separator: "\n"))
        #expect(SkhdConfig.parse(disabled).map(\.key) == ["h"])
        #expect(SkhdConfig.disable(text, line: 0) == disabled)

        let rebound = try #require(
            SkhdConfig.rebind(text, binding: binding, modifiers: ["alt"], key: "x"))
        #expect(rebound == text.replacingOccurrences(of: "cmd - x", with: "alt - x"))
    }

    @Test("an escaped backslash at the end of a line does not continue it")
    func escapedBackslash() {
        let parsed = SkhdConfig.parse("cmd - a : echo \\\\\ncmd - b : echo b")
        #expect(parsed.map(\.key) == ["a", "b"])
        #expect(parsed.first?.endLine == 0)
    }

    @Test("a commented entry inside a per-app block is not an override")
    func commentInBlock() throws {
        let text = "cmd - n [\n  # \"Safari\" : old\n  \"Firefox\" : echo ff\n]"
        let binding = try #require(SkhdConfig.parse(text).first)
        #expect(binding.appOverrides.map(\.app) == ["Firefox"])
    }

    /// `.blacklist` lists applications skhd ignores. Read as a per-app block,
    /// a one-line list swallowed every shortcut down to the next `]`, and a
    /// multi-line list became a shortcut whose rebind rewrote `.blacklist`.
    @Test("a one-line blacklist is left alone and hides nothing")
    func oneLineIgnoreList() {
        let text = """
            .blacklist [ "kitty" "terminal" ]
            alt - h : yabai -m window --focus west
            alt - l : yabai -m window --focus east
            cmd - n [
                "Safari" : echo safari
                * : echo other
            ]
            """
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.map(\.key) == ["h", "l", "n"])
        #expect(parsed.last?.appOverrides.map(\.app) == ["Safari", "*"])
    }

    @Test("a multi-line blacklist is not a shortcut")
    func multiLineIgnoreList() {
        let text = ".blacklist [\n  \"kitty\"\n  \"my [app]\"\n]\nalt - h : echo"
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.map(\.key) == ["h"])
        #expect(parsed.first?.id == 4)
    }

    @Test("other options are not shortcuts and do not name a section")
    func otherOptions() {
        let text = "# Load more\n.load \"extra: skhdrc\"\n.shell \"/bin/dash\"\nalt - h : echo"
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.map(\.key) == ["h"])
        #expect(parsed.first?.section == nil)
    }

    /// Rebinding `resize < h` used to drop the prefix and move the shortcut
    /// into the default mode.
    @Test("a mode prefix survives a rebind")
    func modeKeptOnRebind() throws {
        let text = ":: resize @\nresize < h : yabai -m window --resize left:-20:0"
        let binding = try #require(SkhdConfig.parse(text).first)
        #expect(binding.modes == ["resize"])
        #expect(binding.key == "h" && binding.modifiers.isEmpty)
        let rebound = SkhdConfig.rebind(text, binding: binding, modifiers: ["alt"], key: "j")
        #expect(rebound == ":: resize @\nresize < alt - j : yabai -m window --resize left:-20:0")
        #expect(SkhdConfig.parse(rebound ?? "").first?.modes == ["resize"])
    }

    @Test("several modes and a passthrough survive a rebind")
    func modesAndPassthrough() throws {
        let text = "  default, resize < cmd - k -> : echo k"
        let binding = try #require(SkhdConfig.parse(text).first)
        #expect(binding.modes == ["default", "resize"])
        #expect(binding.passthrough)
        #expect(
            SkhdConfig.rebind(text, binding: binding, modifiers: ["ctrl"], key: "k")
                == "  default, resize < ctrl - k -> : echo k")
    }

    /// `; mode` bindings were not listed at all, so the conflict check could
    /// not see the chords they occupy.
    @Test("mode switches are listed and keep their target on rebind")
    func modeSwitches() throws {
        let text =
            "cmd - r ; resize\nresize < escape ; default\nresize < return : echo hi ; default"
        let parsed = SkhdConfig.parse(text)
        #expect(parsed.map(\.key) == ["r", "escape", "return"])
        #expect(parsed.map(\.activatesMode) == ["resize", "default", nil])
        #expect(parsed[0].command.isEmpty)
        #expect(parsed[2].command == "echo hi ; default")
        #expect(
            SkhdConfig.rebind(text, binding: parsed[0], modifiers: ["alt"], key: "r")
                == "alt - r ; resize\nresize < escape ; default\nresize < return : echo hi ; default"
        )
        #expect(
            SkhdConfig.disable(text, binding: parsed[1])
                == "cmd - r ; resize\n# resize < escape ; default\nresize < return : echo hi ; default"
        )
    }

    @Test("a chord conflicts only with bindings in the same mode")
    func conflictsByMode() throws {
        let text = "cmd - r ; resize\nresize < h : echo shrink\nalt - h : echo focus"
        let parsed = SkhdConfig.parse(text)
        let inResize = parsed[1]
        let global = parsed[2]
        #expect(
            SkhdConfig.conflict(in: parsed, modifiers: ["cmd"], key: "r", excluding: global)?.id
                == 0)
        #expect(
            SkhdConfig.conflict(in: parsed, modifiers: ["cmd"], key: "r", excluding: nil)?.id == 0)
        #expect(
            SkhdConfig.conflict(in: parsed, modifiers: [], key: "h", excluding: global) == nil)
        #expect(
            SkhdConfig.conflict(in: parsed, modifiers: ["alt"], key: "h", excluding: inResize)
                == nil)
        #expect(
            SkhdConfig.conflict(in: parsed, modifiers: ["alt"], key: "h", excluding: nil)?.id == 2)
    }

    @Test("a mode declaration is not a shortcut")
    func modeDeclaration() {
        let text = ":: resize @ : echo entering: resize \\\n  now\nalt - h : echo"
        #expect(SkhdConfig.parse(text).map(\.key) == ["h"])
    }

    @Test("an unterminated block is not offered for editing")
    func unterminatedBlock() {
        #expect(SkhdConfig.parse("cmd - w [\n    * : echo").isEmpty)
    }
}
