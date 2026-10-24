import Foundation
import Testing

@testable import Macarchy

/// Edits from the Shortcuts page go into a file the person wrote by hand, so
/// every construct skhd accepts has to come back out exactly as it went in.
/// The fixture is spelled the way the writer spells a chord, so rebinding a
/// shortcut to its own chord must reproduce the file byte for byte.
@Suite("SkhdConfig round trips")
struct SkhdRoundTripTests {
    static let fixture = """
        # Macarchy shortcuts, edited by hand.
        .shell "/bin/dash"
        .load "/Users/me/.config/skhd/extra"

        # Leave terminals alone
        .blacklist [ "kitty" "terminal" ]
        .blacklist [
            "Screen Sharing"
            "my [app]"
        ]

        # Focus windows
        ctrl + alt - left : yabai -m window --focus west
        # ctrl + alt - up : yabai -m window --focus north
        ctrl + alt - right : yabai -m window --focus east

        # Grow and shrink, by keycode
        ctrl + alt - 0x18 : yabai -m window --ratio rel:0.05
        ctrl + alt - 0x1B : yabai -m window --ratio rel:-0.05

        # Quit with a notice, continued over lines
        cmd - x : yabai -m window --focus west \\
          || osascript -e 'display notification "a: b"'
            alt - y : echo one \\
              two: three \\
              four

        # Pass the key on
        cmd - q -> : open -a Finder
        cmd - w -> [
            "Messages" : osascript -e 'quit app "Messages"'
            # "Notes" : echo retired
            "Safari" : echo one \\
                two
            * : skhd -k "cmd - w"
        ]

        play : osascript -e 'tell application "Spotify" to playpause'

        # Resize mode
        :: resize @ : echo entering \\
            resize: now
        cmd - r ; resize
        resize < escape ; default
        resize < h : yabai -m window --resize left:-20:0
        default, resize < shift - h -> : echo both
        """

    static var lines: [String] { fixture.components(separatedBy: "\n") }

    /// The shortcuts skhd sees; the fixture also holds one the page disabled.
    static var live: [SkhdBinding] { SkhdConfig.parse(fixture).filter { !$0.isDisabled } }

    @Test("parses every shortcut in the fixture once")
    func parsesFixture() {
        let bindings = SkhdConfig.parse(Self.fixture)
        #expect(
            bindings.map(\.key) == [
                "left", "up", "right", "0x18", "0x1B", "x", "y", "q", "w", "play", "r", "escape",
                "h",
                "h"
            ])
    }

    @Test("rebinding a shortcut to its own chord leaves the file byte for byte")
    func identityRebind() throws {
        for binding in Self.live {
            let rewritten = SkhdConfig.rebind(
                Self.fixture, binding: binding, modifiers: binding.modifiers, key: binding.key)
            #expect(rewritten == Self.fixture, "line \(binding.id)")
        }
    }

    @Test("rebinding changes only the first line of the shortcut")
    func rebindTouchesOneLine() throws {
        let before = SkhdConfig.parse(Self.fixture)
        for binding in Self.live {
            let rewritten = try #require(
                SkhdConfig.rebind(Self.fixture, binding: binding, modifiers: ["hyper"], key: "z"))
            let lines = rewritten.components(separatedBy: "\n")
            #expect(lines.count == Self.lines.count)
            for index in lines.indices where index != binding.id {
                #expect(lines[index] == Self.lines[index], "line \(index)")
            }
            let after = SkhdConfig.parse(rewritten)
            #expect(after.count == before.count)
            let moved = try #require(after.first { $0.id == binding.id })
            #expect(moved.key == "z" && moved.modifiers == ["hyper"])
            #expect(moved.command == binding.command)
            #expect(moved.endLine == binding.endLine)
            #expect(moved.passthrough == binding.passthrough)
            #expect(moved.appOverrides == binding.appOverrides)
            #expect(moved.modes == binding.modes)
            #expect(moved.activatesMode == binding.activatesMode)
        }
    }

    @Test("disabling comments out exactly the shortcut's lines")
    func disableTouchesItsLines() throws {
        let before = SkhdConfig.parse(Self.fixture)
        for binding in Self.live {
            let disabled = try #require(SkhdConfig.disable(Self.fixture, binding: binding))
            let lines = disabled.components(separatedBy: "\n")
            #expect(lines.count == Self.lines.count)
            for index in lines.indices {
                let line = Self.lines[index]
                let expected =
                    switch index {
                    case binding.id: "# disabled: " + line
                    case binding.id...binding.endLine: "# " + line
                    default: line
                    }
                #expect(lines[index] == expected, "line \(index)")
            }
            // Every other shortcut is unchanged, section included: the
            // disabled binding's comment must not become a heading.
            func shape(_ b: SkhdBinding) -> String {
                "\(b.id) \(b.section ?? "-") \(b.modes) \(b.modifiers) \(b.key) \(b.command) "
                    + "\(b.appOverrides) \(b.activatesMode ?? "-") \(b.endLine)"
            }
            let after = SkhdConfig.parse(disabled)
            #expect(after.map(shape) == before.map(shape))
            #expect(
                Set(after.filter(\.isDisabled).map(\.id))
                    == Set(before.filter(\.isDisabled).map(\.id)).union([binding.id]))
        }
    }

    /// Enable removes exactly what Disable wrote, so the pair is a no-op.
    @Test("disabling then enabling gives back the original bytes")
    func disableThenEnable() throws {
        for binding in Self.live {
            let disabled = try #require(SkhdConfig.disable(Self.fixture, binding: binding))
            let parsed = try #require(SkhdConfig.parse(disabled).first { $0.id == binding.id })
            #expect(parsed.isDisabled)
            #expect(
                SkhdConfig.enable(disabled, binding: parsed) == Self.fixture, "line \(binding.id)")
        }
    }

    @Test("a disabled binding in the file enables, and edits refuse it")
    func enableFromFile() throws {
        let up = try #require(SkhdConfig.parse(Self.fixture).first { $0.key == "up" })
        #expect(up.isDisabled)
        #expect(SkhdConfig.disable(Self.fixture, binding: up) == nil)
        #expect(SkhdConfig.rebind(Self.fixture, binding: up, modifiers: ["alt"], key: "u") == nil)
        let enabled = try #require(SkhdConfig.enable(Self.fixture, binding: up))
        #expect(
            enabled
                == Self.fixture.replacingOccurrences(
                    of: "# ctrl + alt - up", with: "ctrl + alt - up"))
        #expect(SkhdConfig.enable(enabled, binding: up) == nil)
    }

    @Test("a disabled binding is listed in its section, not read as a heading")
    func disabledBindingIsNotAHeading() throws {
        let bindings = SkhdConfig.parse(Self.fixture)
        let right = try #require(bindings.first { $0.key == "right" })
        let up = try #require(bindings.first { $0.key == "up" })
        #expect(right.section == "Focus windows" && up.section == "Focus windows")
        #expect(up.isDisabled && !right.isDisabled)
        #expect(
            SkhdConfig.conflict(in: bindings, modifiers: ["ctrl", "alt"], key: "up", excluding: nil)
                == nil)
    }
}
