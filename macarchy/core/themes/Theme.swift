import Foundation

/// A theme as portable data.
///
/// A manifest is inert data: it can be validated before use, diffed against a
/// default and carry a version. Nothing in a theme is ever executed.
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

    /// Maps manifest colours to the flat keys integrations read.
    private static var colorKeys: [(WritableKeyPath<Colors, String?>, String)] {
        [
            (\.borderActive, "BORDER_ACTIVE"),
            (\.borderInactive, "BORDER_INACTIVE"),
            (\.sketchybarBar, "SKETCHYBAR_BAR_COLOR"),
            (\.sketchybarText, "SKETCHYBAR_TEXT_COLOR"),
            (\.firefoxAccent, "FIREFOX_ACCENT")
        ]
    }

    /// The manifest as flat values, keyed the way integrations consume them.
    public func flatValues() -> [String: String] {
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
        if let scheme = apps.nvimColorscheme, !NeovimColourschemes.isValidName(scheme) {
            throw ConfigurationError("Invalid Neovim colourscheme name: \(scheme)")
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
