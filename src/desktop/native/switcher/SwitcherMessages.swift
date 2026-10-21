import Foundation
import Macarchy

// Mirrors `src/desktop/ui/src/bridge/contract/switcher.ts`.

struct SwitcherState: Codable, Sendable, Equatable {
    var themes: [ThemeSummary]
    var current: String?
}

struct ThemeSummary: Codable, Sendable, Equatable {
    var name: String
    var title: String
    var isDark: Bool
    var ring: String
    var colours: TerminalColours?
    var currentBackground: String?
    var preview: String?
    var backgrounds: [Background]

    struct TerminalColours: Codable, Sendable, Equatable {
        var background: String
        var foreground: String
        var red: String
        var green: String
        var blue: String
        var cyan: String
    }

    struct Background: Codable, Sendable, Equatable {
        var path: String
        var name: String
        var thumbnail: String
    }
}

struct ThemeParams: Codable, Sendable {
    var theme: String
}

struct BackgroundParams: Codable, Sendable {
    var theme: String
    var path: String
}

// Synthesised encoding leaves nil optionals out; the contract declares them as
// `T | null`, so these spell them out.

extension SwitcherState {
    private enum CodingKeys: String, CodingKey { case themes, current }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themes, forKey: .themes)
        try container.encode(current, forKey: .current)
    }
}

extension ThemeSummary {
    private enum CodingKeys: String, CodingKey {
        case name, title, isDark, ring, colours, currentBackground, preview, backgrounds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(isDark, forKey: .isDark)
        try container.encode(ring, forKey: .ring)
        try container.encode(colours, forKey: .colours)
        try container.encode(currentBackground, forKey: .currentBackground)
        try container.encode(preview, forKey: .preview)
        try container.encode(backgrounds, forKey: .backgrounds)
    }
}

extension BridgeEvent {
    static func themesChanged(_ state: SwitcherState) -> BridgeEvent {
        BridgeEvent("themes.changed", state: state)
    }

    /// The page resets to this state and resolves once it has drawn it.
    static func switcherWillOpen(_ state: SwitcherState) -> BridgeEvent {
        BridgeEvent("switcher.willOpen", state: state)
    }

    static let switcherDidClose = BridgeEvent("switcher.didClose")
}

/// What the switcher is sent, built from the catalogue the status menu reads.
extension AppModel {
    func switcherState() -> SwitcherState {
        SwitcherState(themes: themes.themes.map(\.summary), current: themes.current)
    }
}

extension InstalledTheme {
    /// "city-783" reads as "City 783".
    var title: String {
        name.split(whereSeparator: { "-_ ".contains($0) })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var summary: ThemeSummary {
        let backgrounds = SwitcherBackground.all(in: self)
        let current = wallpaperURL.map { $0.standardizedFileURL }
        let currentPath = backgrounds.first { $0.url.standardizedFileURL == current }?.relativePath
        let accent = TerminalPalette.rgb(manifest?.colors.borderActive) ?? "#0a84ff"
        return ThemeSummary(
            name: name,
            title: title,
            isDark: isDark,
            // The ANSI blue, as the Raycast list this replaces used.
            ring: terminal.flatMap { $0.ansi.isEmpty ? nil : $0.ansi(4) } ?? accent,
            colours: terminal.map {
                .init(
                    background: $0.background, foreground: $0.foreground, red: $0.ansi(1),
                    green: $0.ansi(2), blue: $0.ansi(4), cyan: $0.ansi(6))
            },
            currentBackground: currentPath,
            preview: currentPath.map {
                AppScheme.themeImageURL(theme: name, path: $0, maxPixels: 1400)
            },
            backgrounds: backgrounds.map {
                .init(
                    path: $0.relativePath, name: $0.name,
                    thumbnail: AppScheme.themeImageURL(
                        theme: name, path: $0.relativePath, maxPixels: 700))
            })
    }
}
