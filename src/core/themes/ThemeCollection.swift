import Foundation

/// Installed theme data shared by the native catalogue and settings bridge.
public struct ThemeCollection: Sendable {
    public let library: ThemeLibrary
    public let resources: URL?

    public init(root: URL = Paths.themesDirectory, resources: URL? = Paths.resources) {
        library = ThemeLibrary(root: root)
        self.resources = resources
    }

    public struct Entry: Sendable {
        public let name: String
        public let directory: URL
        public let manifest: Theme
        public let terminal: TerminalPalette?
    }

    public struct Snapshot: Sendable {
        public let themes: [Entry]
        public let current: String?
        public let wallpapers: [String: String]
        public let warnings: [String]
    }

    /// A missing collection is normal before setup. Unreadable settings are not.
    public func read(store: SettingsStore = SettingsStore()) throws -> Snapshot {
        let settings = try store.read()
        let fm = FileManager.default
        let entries =
            fm.fileExists(atPath: library.root.path)
            ? try fm.contentsOfDirectory(
                at: library.root, includingPropertiesForKeys: [.isDirectoryKey]) : []
        var warnings: [String] = []
        let themes = entries.filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { directory -> Entry? in
                guard
                    (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                else { return nil }
                do {
                    guard
                        directory.resolvingSymlinksInPath().path.hasPrefix(
                            library.root.resolvingSymlinksInPath().path + "/")
                    else {
                        throw ConfigurationError("Theme files must stay inside the theme folder")
                    }
                    let theme = try Theme.read(from: directory)
                    guard theme.name == directory.lastPathComponent else {
                        throw ConfigurationError("Theme folder and manifest name disagree")
                    }
                    let palette = try theme.palette(in: directory).map(TerminalPalette.parse)
                    return Entry(
                        name: theme.name, directory: directory, manifest: theme, terminal: palette)
                } catch {
                    warnings.append("\(directory.lastPathComponent): \(error.localizedDescription)")
                    return nil
                }
            }
        return Snapshot(
            themes: themes, current: settings.currentTheme, wallpapers: settings.wallpapers,
            warnings: warnings)
    }

    public func directory(named name: String) throws -> URL {
        try Theme(name: name).validate()
        let root = library.root.resolvingSymlinksInPath()
        let directory = root.appending(path: name).resolvingSymlinksInPath()
        guard directory.path.hasPrefix(root.path + "/") else {
            throw ConfigurationError("Theme files must stay inside the theme folder")
        }
        let manifest = try Theme.read(from: directory)
        guard manifest.name == name else {
            throw ConfigurationError("Theme folder and manifest name disagree")
        }
        return directory
    }

    public func bundledDefault(named name: String) -> Theme? {
        guard (try? Theme(name: name).validate()) != nil, let resources else { return nil }
        return Theme.load(from: resources.appending(path: "themes/\(name)"))
    }

    public enum Colour: String, Codable, Sendable {
        case borderActive, borderInactive, sketchybarBar, sketchybarText, firefoxAccent

        var keyPath: WritableKeyPath<Theme.Colors, String?> {
            switch self {
            case .borderActive: \.borderActive
            case .borderInactive: \.borderInactive
            case .sketchybarBar: \.sketchybarBar
            case .sketchybarText: \.sketchybarText
            case .firefoxAccent: \.firefoxAccent
            }
        }
    }

    public func setDark(theme name: String, dark: Bool) throws {
        try edit(name) { $0.dark = dark }
    }

    public func setColour(theme name: String, colour: Colour, value: String) throws {
        try edit(name) { $0.colors[keyPath: colour.keyPath] = value }
    }

    public func setColourscheme(theme name: String, value: String?) throws {
        try edit(name) { $0.apps.nvimColorscheme = value }
    }

    public func reset(theme name: String) throws {
        guard let original = bundledDefault(named: name) else {
            throw ConfigurationError("No shipped default for \(name)")
        }
        try library.save(
            original, to: directory(named: name),
            reason: "reset theme \(name) to its shipped version")
    }

    private func edit(_ name: String, change: (inout Theme) -> Void) throws {
        let directory = try directory(named: name)
        var manifest = try Theme.read(from: directory)
        change(&manifest)
        try library.save(manifest, to: directory)
    }

    /// Only theme-owned images can be offered to a web page or selected there.
    public static func backgrounds(in directory: URL) -> [URL] {
        let fm = FileManager.default
        let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]
        let root = directory.resolvingSymlinksInPath().path + "/"
        return [directory.appending(path: "backgrounds"), directory].flatMap {
            (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.isRegularFileKey]))
                ?? []
        }.filter {
            extensions.contains($0.pathExtension.lowercased())
                && $0.resolvingSymlinksInPath().path.hasPrefix(root)
                && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
