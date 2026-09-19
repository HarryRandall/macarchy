import Foundation

/// A theme as portable data.
///
/// `theme.env` is shell that gets `source`d by bordersrc, which makes an
/// imported theme arbitrary code at login. A manifest is inert data: it can be
/// validated before use, diffed against a default, and carry a version.
///
/// The env file is not replaced — it is *generated* from this, so theme-switch
/// and bordersrc keep working untouched.
public struct Theme: Codable, Sendable, Equatable {
    public var schema: Int = 1
    public var name: String
    public var displayName: String?
    public var version: String?
    public var author: String?
    public var dark: Bool = true
    public var wallpaper: String?
    public var colors: Colors = Colors()
    public var apps: Apps = Apps()

    public struct Colors: Codable, Sendable, Equatable {
        public init() {}

        public var borderActive: String?
        public var borderInactive: String?
        public var sketchybarBar: String?
        public var sketchybarText: String?
        public var firefoxAccent: String?
    }

    public struct Apps: Codable, Sendable, Equatable {
        public init() {}

        public var nvimColorscheme: String?
        public var ghosttyConfig: String?
    }

    public init(
        schema: Int = 1,
        name: String,
        displayName: String? = nil,
        version: String? = nil,
        author: String? = nil,
        dark: Bool = true,
        wallpaper: String? = nil,
        colors: Colors = Colors(),
        apps: Apps = Apps()
    ) {
        self.schema = schema
        self.name = name
        self.displayName = displayName
        self.version = version
        self.author = author
        self.dark = dark
        self.wallpaper = wallpaper
        self.colors = colors
        self.apps = apps
    }

    public static let fileName = "theme.json"

    /// Maps manifest fields to the env keys the existing shell already reads.
    /// One table drives both directions so they cannot drift apart.
    private static var colorKeys: [(WritableKeyPath<Colors, String?>, String)] {
        [
            (\.borderActive, "BORDER_ACTIVE"),
            (\.borderInactive, "BORDER_INACTIVE"),
            (\.sketchybarBar, "SKETCHYBAR_BAR_COLOR"),
            (\.sketchybarText, "SKETCHYBAR_TEXT_COLOR"),
            (\.firefoxAccent, "FIREFOX_ACCENT")
        ]
    }

    // MARK: - Writing the legacy format

    /// Regenerates the env file the shell still consumes.
    public func envRepresentation() -> String {
        func escaped(_ value: String) -> String {
            value.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "`", with: "\\`")
        }
        var lines = [
            "# Generated from \(Self.fileName) by Macarchy Settings — do not edit by hand.",
            "DARK_MODE=\(dark)"
        ]
        if let wallpaper { lines.append("WALLPAPER=\"\(escaped(wallpaper))\"") }
        if let scheme = apps.nvimColorscheme {
            lines.append("NVIM_COLORSCHEME=\"\(escaped(scheme))\"")
        }
        for (keyPath, envKey) in Self.colorKeys {
            if let value = colors[keyPath: keyPath] {
                lines.append("\(envKey)=\"\(escaped(value))\"")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The env dictionary this manifest represents, for comparing against an
    /// existing file without writing anything.
    public func envValues() -> [String: String] {
        var values: [String: String] = ["DARK_MODE": String(dark)]
        if let wallpaper { values["WALLPAPER"] = wallpaper }
        if let scheme = apps.nvimColorscheme { values["NVIM_COLORSCHEME"] = scheme }
        for (keyPath, envKey) in Self.colorKeys {
            if let value = colors[keyPath: keyPath] { values[envKey] = value }
        }
        return values
    }

    // MARK: - Disk

    public static func read(from directory: URL) throws -> Theme {
        let theme = try JSONDecoder().decode(
            Theme.self, from: Data(contentsOf: directory.appending(path: fileName)))
        try theme.validate()
        return theme
    }

    public static func load(from directory: URL) -> Theme? { try? read(from: directory) }

    public func validate() throws {
        guard schema == 1, !name.isEmpty,
            name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression) != nil
        else { throw ConfigurationError("Invalid theme name or unsupported schema") }
        for path in [wallpaper, apps.ghosttyConfig].compactMap({ $0 }) {
            guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
                throw ConfigurationError("Theme assets must stay inside the theme folder")
            }
        }
        for colour in [
            colors.borderActive, colors.borderInactive, colors.sketchybarBar, colors.sketchybarText,
            colors.firefoxAccent
        ].compactMap({ $0 }) {
            guard
                colour.range(
                    of: "^(0x[0-9a-fA-F]{8}|#[0-9a-fA-F]{6})$", options: .regularExpression) != nil
            else {
                throw ConfigurationError("Invalid theme colour: \(colour)")
            }
        }
    }

    public func write(to directory: URL) throws {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(
            to: directory.appending(path: Self.fileName), options: .atomic)
    }
}
