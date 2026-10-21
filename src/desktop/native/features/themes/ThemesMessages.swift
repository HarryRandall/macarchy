import Foundation
import Macarchy

// Mirrors `bridge/contract/themes.ts`. Optional values are explicit nulls.
struct ThemesState: Codable, Sendable {
    var themes: [ThemeDetail]
    var current: String?
    var colourschemes: [String]
    var warnings: [String]

    enum CodingKeys: String, CodingKey { case themes, current, colourschemes, warnings }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themes, forKey: .themes)
        try container.encode(current, forKey: .current)
        try container.encode(colourschemes, forKey: .colourschemes)
        try container.encode(warnings, forKey: .warnings)
    }
}

struct ThemeDetail: Codable, Sendable {
    var summary: ThemeSummary
    var values: ThemeEditorValues
    var modified: Bool
    var hasDefault: Bool
    var defaultColourscheme: String
    var terminal: ThemeTerminal?

    enum CodingKeys: String, CodingKey {
        case summary, values, modified, hasDefault, defaultColourscheme, terminal
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(summary, forKey: .summary)
        try container.encode(values, forKey: .values)
        try container.encode(modified, forKey: .modified)
        try container.encode(hasDefault, forKey: .hasDefault)
        try container.encode(defaultColourscheme, forKey: .defaultColourscheme)
        try container.encode(terminal, forKey: .terminal)
    }
}

struct ThemeTerminal: Codable, Sendable {
    var background: String
    var foreground: String
    var cursor: String
    var ansi: [String]
}

struct ThemeEditorValues: Codable, Sendable {
    var dark: Bool
    var borderActive: String?
    var borderInactive: String?
    var sketchybarBar: String?
    var sketchybarText: String?
    var firefoxAccent: String?
    var nvimColorscheme: String?

    init(_ theme: Theme) {
        dark = theme.dark
        borderActive = theme.colors.borderActive
        borderInactive = theme.colors.borderInactive
        sketchybarBar = theme.colors.sketchybarBar
        sketchybarText = theme.colors.sketchybarText
        firefoxAccent = theme.colors.firefoxAccent
        nvimColorscheme = theme.apps.nvimColorscheme
    }

    enum CodingKeys: String, CodingKey {
        case dark, borderActive, borderInactive, sketchybarBar, sketchybarText, firefoxAccent
        case nvimColorscheme
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dark, forKey: .dark)
        try container.encode(borderActive, forKey: .borderActive)
        try container.encode(borderInactive, forKey: .borderInactive)
        try container.encode(sketchybarBar, forKey: .sketchybarBar)
        try container.encode(sketchybarText, forKey: .sketchybarText)
        try container.encode(firefoxAccent, forKey: .firefoxAccent)
        try container.encode(nvimColorscheme, forKey: .nvimColorscheme)
    }
}

struct ThemeDarkParams: Decodable { var theme: String; var dark: Bool }
struct ThemeColourParams: Decodable {
    var theme: String
    var colour: ThemeCollection.Colour
    var value: String
}
struct ThemeColourschemeParams: Decodable { var theme: String; var value: String? }

extension AppModel {
    func themesState() throws -> ThemesState {
        try themes.refresh()
        let details = themes.themes.compactMap { installed -> ThemeDetail? in
            guard var manifest = installed.manifest else { return nil }
            let values = ThemeEditorValues(manifest)
            manifest.apps.nvimColorscheme = nil
            return ThemeDetail(
                summary: installed.summary, values: values,
                modified: themes.isModified(installed),
                hasDefault: themes.hasDefault(installed),
                defaultColourscheme: ThemeOutputs(theme: manifest, ghostty: "").nvim,
                terminal: installed.terminal.map {
                    ThemeTerminal(
                        background: $0.background, foreground: $0.foreground,
                        cursor: $0.cursor, ansi: (0...15).map($0.ansi))
                })
        }
        return ThemesState(
            themes: details, current: themes.current,
            colourschemes: NeovimColourschemes.discover(), warnings: themes.warnings)
    }
}
