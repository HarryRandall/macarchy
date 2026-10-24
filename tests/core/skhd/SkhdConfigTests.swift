import Foundation
import Testing

@testable import Macarchy

/// skhd exposes no parser, so this one is ours. The cases are the three forms
/// that actually appear in the config being migrated.
@Suite("SkhdConfig")
struct SkhdConfigTests {
    @Test("parses a standard binding")
    func standardBinding() {
        let bindings = SkhdConfig.parse("cmd + shift - h : yabai -m window --swap west")
        #expect(bindings.count == 1)
        #expect(bindings[0].modifiers == ["cmd", "shift"])
        #expect(bindings[0].key == "h")
        #expect(bindings[0].command == "yabai -m window --swap west")
    }

    /// Media keys carry no modifier at all.
    @Test("parses a modifier-less media key")
    func mediaKey() {
        let bindings = SkhdConfig.parse(
            "play : osascript -e 'tell application \"Spotify\" to playpause'")
        #expect(bindings.count == 1)
        #expect(bindings[0].modifiers.isEmpty)
        #expect(bindings[0].key == "play")
    }

    /// Commands routinely contain colons, so only the first separates them.
    @Test("splits on the first colon only")
    func colonsInCommands() {
        let bindings = SkhdConfig.parse("cmd - o : open https://example.com:8080/x")
        #expect(bindings[0].command == "open https://example.com:8080/x")
    }

    @Test("parses an app-specific block")
    func appSpecificBlock() {
        let config = """
            cmd - w -> [
                "Messages"  : osascript -e 'quit'
                "Obsidian"  : osascript -e 'quit'
                *           : skhd -k "cmd - w"
            ]
            """
        let bindings = SkhdConfig.parse(config)
        #expect(bindings.count == 1)
        #expect(bindings[0].passthrough)
        #expect(bindings[0].appOverrides.count == 3)
        #expect(bindings[0].appOverrides.contains { $0.app == "*" })
    }

    @Test("carries the section comment above a binding")
    func sectionComments() {
        let bindings = SkhdConfig.parse("# Focus windows\ncmd - h : yabai -m window --focus west")
        #expect(bindings[0].section == "Focus windows")
    }

    @Test("renders hex keycodes as their character")
    func hexKeycodes() {
        let bindings = SkhdConfig.parse("cmd + ctrl - 0x18 : theme-switch next")
        #expect(bindings[0].keyCaps.last == "=")
    }

    /// Disabling writes `# ` before the binding. That comment used to join
    /// the heading above, renaming the section of every shortcut below it.
    @Test("disabling keeps the section of the shortcuts below")
    func disableKeepsSections() throws {
        let text = """
            # Focus windows
            ctrl + alt - left : yabai -m window --focus west
            ctrl + alt - right : yabai -m window --focus east
            cmd - w [
                * : echo close
            ]
            """
        let parsed = SkhdConfig.parse(text)
        let first = try #require(SkhdConfig.disable(text, binding: parsed[0]))
        let block = try #require(SkhdConfig.disable(first, binding: parsed[2]))
        let after = SkhdConfig.parse(block)
        #expect(after.map(\.key) == ["left", "right", "w"])
        #expect(after.map(\.isDisabled) == [true, false, true])
        #expect(after.allSatisfy { $0.section == "Focus windows" })
    }

    /// A heading that starts with a key name used to read as a disabled
    /// binding, and Enable would then have bound the bare key everywhere.
    @Test("headings named after keys stay headings and keep their section")
    func keyNamedHeadings() throws {
        let text = """
            # Windows
            ctrl - h : yabai -m window --focus west

            # Space: switch desktops
            ctrl - 1 : yabai -m space --focus 1
            ctrl - 2 : yabai -m space --focus 2

            # Play: media keys below
            play : echo play

            # Next: the theme keys
            # Home: first
            # Return: confirm
            # Up: move
            cmd - n : echo next
            """
        let bindings = SkhdConfig.parse(text)
        #expect(bindings.map(\.key) == ["h", "1", "2", "play", "n"])
        #expect(bindings.allSatisfy { !$0.isDisabled })
        let sections = [
            "Windows", "Space: switch desktops", "Space: switch desktops",
            "Play: media keys below", "Next: the theme keys Home: first Return: confirm Up: move"
        ]
        #expect(bindings.map(\.section) == sections)

        // Disabling any shortcut, a bare media key included, lists it as
        // disabled in its own section, leaves the others alone, and Enable
        // gives back the original bytes.
        for binding in bindings {
            let disabled = try #require(SkhdConfig.disable(text, binding: binding))
            let after = SkhdConfig.parse(disabled)
            #expect(after.map(\.key) == bindings.map(\.key))
            #expect(after.map(\.section) == sections, "\(binding.key)")
            let expected = bindings.map { $0.id == binding.id }
            #expect(after.map(\.isDisabled) == expected)
            let parsed = try #require(after.first { $0.id == binding.id })
            #expect(SkhdConfig.enable(disabled, binding: parsed) == text, "\(binding.key)")
        }
    }

    /// Disabling a per-app block used to write `# ` on its blank lines, which
    /// editors that trim trailing spaces cut to `#`, breaking the block apart.
    @Test("a disabled per-app block survives trimmed blank lines")
    func disabledBlockWithBlankLine() throws {
        let text = """
            # Apps
            cmd - h [
                "kitty" : echo k

                * : echo all
            ]
            ctrl - x : echo x
            """
        let block = try #require(SkhdConfig.parse(text).first)
        let disabled = try #require(SkhdConfig.disable(text, binding: block))
        #expect(disabled.components(separatedBy: "\n")[3] == "#")
        // The same block as an earlier build wrote it, after an editor trimmed it.
        let legacy = disabled.replacingOccurrences(of: "# disabled: cmd", with: "# cmd")
        for file in [disabled, legacy] {
            let after = SkhdConfig.parse(file)
            #expect(after.map(\.key) == ["h", "x"])
            #expect(after.map(\.isDisabled) == [true, false])
            #expect(after.map(\.section) == ["Apps", "Apps"])
            #expect(after.first?.appOverrides.map(\.app) == ["kitty", "*"])
            let parsed = try #require(after.first)
            #expect(SkhdConfig.enable(file, binding: parsed) == text)
        }
    }

    @Test("prose comments that look a little like bindings stay headings")
    func proseComments() {
        let text = "# Note: keep these together\n# Move - then: follow\nalt - h : echo"
        #expect(
            SkhdConfig.parse(text).first?.section
                == "Note: keep these together Move - then: follow")
    }
}
