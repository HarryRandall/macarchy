import Foundation
import Testing

@testable import Desktop

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
        let bindings = SkhdConfig.parse("play : osascript -e 'tell application \"Spotify\" to playpause'")
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
}
