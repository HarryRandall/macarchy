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
        """

    static var lines: [String] { fixture.components(separatedBy: "\n") }

    @Test("parses every shortcut in the fixture once")
    func parsesFixture() {
        let bindings = SkhdConfig.parse(Self.fixture)
        #expect(
            bindings.map(\.key) == ["left", "right", "0x18", "0x1B", "x", "y", "q", "w", "play"])
    }

    @Test("rebinding a shortcut to its own chord leaves the file byte for byte")
    func identityRebind() throws {
        for binding in SkhdConfig.parse(Self.fixture) {
            let rewritten = SkhdConfig.rebind(
                Self.fixture, binding: binding, modifiers: binding.modifiers, key: binding.key)
            #expect(rewritten == Self.fixture, "line \(binding.id)")
        }
    }

    @Test("rebinding changes only the first line of the shortcut")
    func rebindTouchesOneLine() throws {
        let before = SkhdConfig.parse(Self.fixture)
        for binding in before {
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
        }
    }

    @Test("disabling comments out exactly the shortcut's lines")
    func disableTouchesItsLines() throws {
        let before = SkhdConfig.parse(Self.fixture)
        for binding in before {
            let disabled = try #require(SkhdConfig.disable(Self.fixture, binding: binding))
            let lines = disabled.components(separatedBy: "\n")
            #expect(lines.count == Self.lines.count)
            for index in lines.indices {
                let expected =
                    (binding.id...binding.endLine).contains(index)
                    ? "# " + Self.lines[index] : Self.lines[index]
                #expect(lines[index] == expected, "line \(index)")
            }
            // Section names can shift when a comment joins the one above, so
            // compare what each remaining shortcut is.
            func shape(_ b: SkhdBinding) -> String {
                "\(b.id) \(b.modifiers) \(b.key) \(b.command) \(b.appOverrides)"
            }
            #expect(
                SkhdConfig.parse(disabled).map(shape)
                    == before.filter { $0.id != binding.id }.map(shape))
        }
    }
}
