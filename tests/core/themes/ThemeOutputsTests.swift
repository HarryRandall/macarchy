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

    /// Themes may spell colours `#rrggbb`; SketchyBar and borders read only
    /// `0xAARRGGBB`.
    @Test func hashColoursReachTheBarAndBordersAsARGB() throws {
        var theme = Theme(name: "t")
        theme.colors.sketchybarBar = "#112233"
        theme.colors.sketchybarText = "#ffffff"
        theme.colors.borderActive = "#ff0000"
        theme.colors.borderInactive = "0x80aabbcc"
        try theme.validate()
        let bar = ThemeOutputs(theme: theme, ghostty: "").barColours
        #expect(bar.contains(#"BAR_COLOR="0xff112233""#))
        #expect(bar.contains(#"TEXT_COLOR="0xffffffff""#))
        #expect(bar.contains(#"ACCENT_COLOR="0xffff0000""#))
        let borders = BorderCommand.arguments(values: [:], theme: theme)
        #expect(borders.contains("active_color=0xffff0000"))
        #expect(borders.contains("inactive_color=0x80aabbcc"))
    }

    /// A palette without `#` themes Ghostty, so it must theme the bar too.
    @Test func paletteColoursWithoutHashReachTheBar() {
        let outputs = ThemeOutputs(
            theme: Theme(name: "t"), ghostty: "foreground = c0c0c0\npalette = 4=0xff3366ff")
        #expect(outputs.barText == "0xffc0c0c0")
        #expect(outputs.barAccent == "0xff3366ff")
        #expect(Theme.argb("0x80aabbcc") == "0x80aabbcc")
    }

    /// A hand-written theme may leave out everything but its schema and
    /// name; mistakes name the file and the key.
    @Test func themeManifestErrorsNameTheFileAndKey() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "theme-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func read(_ json: String) throws -> Result<Theme, any Error> {
            try json.write(
                to: root.appending(path: Theme.fileName), atomically: true, encoding: .utf8)
            return Result { try Theme.read(from: root) }
        }
        let minimal = try read(#"{"schema":1,"name":"x"}"#).get()
        #expect(minimal.dark && minimal.colors == Theme.Colors())
        func message(_ json: String) throws -> String {
            guard case .failure(let error) = try read(json) else { return "read succeeded" }
            return error.localizedDescription
        }
        #expect(try message(#"{"schema":1,"dark":true}"#).hasSuffix("theme.json: name is missing."))
        #expect(
            try message(#"{"schema":1,"name":"x","colors":{"borderActive":5}}"#).hasSuffix(
                "theme.json: colors.borderActive should be text."))
        #expect(
            try message(#"{"schema":1,"name":"x","colors":{"borderActive":"red"}}"#).hasSuffix(
                "theme.json: Invalid theme colour: red"))
        #expect(try message(#"{"schema":2,"name":"x"}"#).contains("newer Macarchy"))
    }
}
