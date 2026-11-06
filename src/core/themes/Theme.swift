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

    /// An opaque colour as `#rrggbb`, from any spelling a theme may use for
    /// one: `#rrggbb`, `rrggbb` or `0xffrrggbb`. Nil for anything else,
    /// including translucent colours and names, which not every tool reads.
    public static func hex(_ colour: String) -> String? {
        let value = colour.trimmingCharacters(in: .whitespaces)
        guard
            let match = value.firstMatch(
                of: /^(?:#|0[xX][fF]{2})?(?<rgb>[0-9a-fA-F]{6})$/)
        else { return nil }
        return "#" + match.output.rgb
    }

    /// A theme colour as SketchyBar and borders read it. Themes may spell
    /// colours as `#rrggbb`; both tools want `0xAARRGGBB`, so an opaque
    /// alpha is added. Other values, such as translucent ones, pass through.
    public static func argb(_ colour: String) -> String {
        hex(colour).map { "0xff" + $0.dropFirst() } ?? colour
    }

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
        let url = directory.appending(path: fileName)
        let theme = try JSONFile.decode(Theme.self, from: url)
        do { try theme.validate() } catch {
            throw ConfigurationError("\(Paths.display(url)): \(error.localizedDescription)")
        }
        return theme
    }

    public static func load(from directory: URL) -> Theme? { try? read(from: directory) }

    public func validate() throws {
        guard schema == 1 else {
            throw ConfigurationError(
                "Theme schema \(schema) is from a newer Macarchy. Update Macarchy to use it.")
        }
        guard name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression) != nil
        else {
            throw ConfigurationError(
                "Invalid theme name \"\(name)\": use letters, digits, - and _, "
                    + "starting with a letter or digit.")
        }
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

extension Theme {
    /// `schema` and `name` are required; the rest may be left out and take
    /// their defaults, as a hand-written theme often does.
    public init(from decoder: Decoder) throws {
        let keys = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schema: try keys.decode(Int.self, forKey: .schema),
            name: try keys.decode(String.self, forKey: .name),
            displayName: try keys.decodeIfPresent(String.self, forKey: .displayName),
            version: try keys.decodeIfPresent(String.self, forKey: .version),
            author: try keys.decodeIfPresent(String.self, forKey: .author),
            dark: try keys.decodeIfPresent(Bool.self, forKey: .dark) ?? true,
            wallpaper: try keys.decodeIfPresent(String.self, forKey: .wallpaper),
            colors: try keys.decodeIfPresent(Colors.self, forKey: .colors) ?? Colors(),
            apps: try keys.decodeIfPresent(Apps.self, forKey: .apps) ?? Apps())
    }
}
