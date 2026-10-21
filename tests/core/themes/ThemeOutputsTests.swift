import Foundation
import Testing
@testable import Macarchy

struct ThemeOutputsTests {
    static let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let fixtures = repository.appending(path: "fixtures/themes")
    static let bundled = repository.deletingLastPathComponent().appending(path: "resources/themes")

    /// Pins each bundled theme's rendered outputs, so a renderer change shows
    /// up as a reviewed fixture diff rather than a silent colour shift.
    @Test(arguments: [
        "awakening", "blackgold", "carbonfox", "city-783", "lumon", "matte-black", "midnight",
        "turbonite"
    ])
    func bundledThemeOutputs(name: String) throws {
        let directory = Self.bundled.appending(path: name)
        let theme = try Theme.read(from: directory)
        let outputs = ThemeOutputs(
            theme: theme, ghostty: try #require(try theme.palette(in: directory)))
        let expected = Self.fixtures.appending(path: name)
        #expect(
            outputs.btop
                == (try String(
                    contentsOf: expected.appending(path: "expected.btop"), encoding: .utf8)))
        #expect(
            outputs.shell
                == (try String(
                    contentsOf: expected.appending(path: "expected.shell"), encoding: .utf8)))
        #expect(outputs.nvim == theme.apps.nvimColorscheme)
    }

    @Test("Neovim falls back to a scheme matching the theme's brightness")
    func neovimFallback() {
        var theme = Theme(name: "plain")
        #expect(ThemeOutputs(theme: theme, ghostty: "").nvim == "tokyonight-night")
        theme.dark = false
        #expect(ThemeOutputs(theme: theme, ghostty: "").nvim == "tokyonight-day")
        theme.apps.nvimColorscheme = "kanagawa"
        #expect(ThemeOutputs(theme: theme, ghostty: "").nvim == "kanagawa")
    }

    @Test func rejectsInvalidThemeNamesAndColours() {
        #expect(throws: (any Error).self) { try Theme(name: "../escape").validate() }
        var theme = Theme(name: "valid")
        theme.colors.borderActive = "invalid"
        #expect(throws: (any Error).self) { try theme.validate() }
    }
}
