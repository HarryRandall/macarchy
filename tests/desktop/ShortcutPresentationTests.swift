import Macarchy
import Testing
@testable import App

struct ShortcutPresentationTests {
    @Test("individual source comments name actions without rewriting the command")
    func sourceLabels() throws {
        let binding = try #require(
            SkhdConfig.parse("# Launch terminal\nctrl - return : open -a Ghostty").first)
        #expect(ShortcutPresentation.label(binding, groupCount: 1) == "Launch terminal")
        #expect(binding.command == "open -a Ghostty")
    }

    @Test("shared source comments do not become duplicate action labels")
    func sharedGroup() throws {
        let bindings = SkhdConfig.parse(
            "# Focus windows\nctrl - h : yabai -m window --focus west\nctrl - l : yabai -m window --focus east"
        )
        #expect(bindings.count == 2)
        #expect(ShortcutPresentation.label(bindings[0], groupCount: 2) == "Focus left")
        #expect(ShortcutPresentation.label(bindings[1], groupCount: 2) == "Focus right")
    }

    @Test("arbitrary shell commands retain their exact spelling")
    func customCommand() throws {
        let binding = try #require(
            SkhdConfig.parse("cmd - p : echo 'Spotify' && do_something_else").first)
        #expect(ShortcutPresentation.label(binding, groupCount: 1) == binding.command)
    }
    @Test("recognised commands must match completely")
    func noPartialMatch() throws {
        let binding = try #require(
            SkhdConfig.parse("cmd - h : yabai -m window --focus west; echo done").first)
        #expect(ShortcutPresentation.label(binding, groupCount: 2) == binding.command)
    }

}
