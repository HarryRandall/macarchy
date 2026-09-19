import Foundation

/// A theme as portable data.
///
/// `theme.env` is shell that gets `source`d by bordersrc, which makes an
/// imported theme arbitrary code at login. A manifest is inert data: it can be
/// validated before use, diffed against a default, and carry a version.
///
/// The env file is not replaced — it is *generated* from this, so theme-switch
/// and bordersrc keep working untouched.
struct ThemeManifest: Codable, Sendable, Equatable {
    var schema: Int = 1
    var name: String
    var displayName: String?
    var version: String?
    var author: String?
    var dark: Bool = true
    var wallpaper: String?
    var colors: Colors = Colors()
    var apps: Apps = Apps()

    struct Colors: Codable, Sendable, Equatable {
        var borderActive: String?
        var borderInactive: String?
        var sketchybarBar: String?
        var sketchybarText: String?
        var firefoxAccent: String?
    }

    struct Apps: Codable, Sendable, Equatable {
        var nvimColorscheme: String?
        var ghosttyConfig: String?
    }

    static let fileName = "theme.json"

    /// Maps manifest fields to the env keys the existing shell already reads.
    /// One table drives both directions so they cannot drift apart.
    private static var colorKeys: [(WritableKeyPath<Colors, String?>, String)] { [
        (\.borderActive, "BORDER_ACTIVE"),
        (\.borderInactive, "BORDER_INACTIVE"),
        (\.sketchybarBar, "SKETCHYBAR_BAR_COLOR"),
        (\.sketchybarText, "SKETCHYBAR_TEXT_COLOR"),
        (\.firefoxAccent, "FIREFOX_ACCENT")
    ] }

    // MARK: - Reading the legacy format

    /// Builds a manifest from an existing theme.env, for migration.
    ///
    /// BORDER_WIDTH is deliberately dropped: it is geometry, which belongs to
    /// settings.env, not to a theme. Keeping it in both is the double-ownership
    /// problem this project is trying to remove.
    static func from(env: [String: String], name: String) -> ThemeManifest {
        var manifest = ThemeManifest(name: name)
        manifest.dark = env["DARK_MODE"] != "false"
        manifest.wallpaper = env["WALLPAPER"]
        manifest.apps.nvimColorscheme = env["NVIM_COLORSCHEME"]
        for (keyPath, envKey) in colorKeys {
            manifest.colors[keyPath: keyPath] = env[envKey]
        }
        return manifest
    }

    // MARK: - Writing the legacy format

    /// Regenerates the env file the shell still consumes.
    func envRepresentation() -> String {
        var lines = [
            "# Generated from \(Self.fileName) by Macarchy Settings — do not edit by hand.",
            "DARK_MODE=\(dark)"
        ]
        if let wallpaper { lines.append("WALLPAPER=\"\(wallpaper)\"") }
        if let scheme = apps.nvimColorscheme { lines.append("NVIM_COLORSCHEME=\"\(scheme)\"") }
        for (keyPath, envKey) in Self.colorKeys {
            if let value = colors[keyPath: keyPath] { lines.append("\(envKey)=\"\(value)\"") }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The env dictionary this manifest represents, for comparing against an
    /// existing file without writing anything.
    func envValues() -> [String: String] {
        var values: [String: String] = ["DARK_MODE": String(dark)]
        if let wallpaper { values["WALLPAPER"] = wallpaper }
        if let scheme = apps.nvimColorscheme { values["NVIM_COLORSCHEME"] = scheme }
        for (keyPath, envKey) in Self.colorKeys {
            if let value = colors[keyPath: keyPath] { values[envKey] = value }
        }
        return values
    }

    // MARK: - Disk

    static func load(from directory: URL) -> ThemeManifest? {
        let url = directory.appending(path: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ThemeManifest.self, from: data)
    }

    func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: directory.appending(path: Self.fileName), options: .atomic)
    }
}
