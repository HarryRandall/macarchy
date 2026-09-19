import Foundation
import Observation
import SwiftUI

enum ThemeError: LocalizedError {
    case notAPackage
    case alreadyInstalled(String)
    case noDefault(String)

    var errorDescription: String? {
        switch self {
        case .notAPackage:
            "That folder has no theme.json, so it isn't a theme package."
        case .alreadyInstalled(let name):
            "A theme called \(name) is already installed. Remove it first, or rename the import."
        case .noDefault(let name):
            "\(name) didn't ship with the app, so there's no default to restore."
        }
    }
}

struct Theme: Identifiable, Sendable {
    let name: String
    let directory: URL
    let values: [String: String]

    var id: String { name }

    var accent: Color {
        Color(macarchyHex: manifest?.colors.borderActive ?? values["BORDER_ACTIVE"]) ?? .accentColor
    }
    var isDark: Bool { manifest?.dark ?? (values["DARK_MODE"] != "false") }
    var colorscheme: String? { manifest?.apps.nvimColorscheme ?? values["NVIM_COLORSCHEME"] }

    /// The background actually in force.
    ///
    /// `.backgrounds.json` records the per-theme choice and overrides the
    /// `WALLPAPER` line in theme.env — for most themes the two already disagree,
    /// so reading theme.env alone would show the wrong image.
    var wallpaperRelativePath: String? { selectedBackground ?? values["WALLPAPER"] }

    var selectedBackground: String?
    var manifest: ThemeManifest?

    /// theme.env is no longer read by the app — it is regenerated from the
    /// manifest purely so bordersrc and theme-switch keep working.
    var envURLLegacy: URL { directory.appending(path: "theme.env") }
    var manifestURL: URL { directory.appending(path: ThemeManifest.fileName) }

    var wallpaperURL: URL? {
        guard let relative = wallpaperRelativePath, !relative.isEmpty else { return nil }
        let url = directory.appending(path: relative)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Every image the theme ships, for the background picker.
    var availableBackgrounds: [URL] {
        let fm = FileManager.default
        let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]
        return [directory.appending(path: "backgrounds"), directory]
            .flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Reads ~/.config/themes. Each theme is a directory holding a `theme.env` of
/// plain KEY="value" lines, which is why no shell parsing is needed here.
@MainActor
@Observable
final class ThemeCatalog {
    private(set) var themes: [Theme] = []
    private(set) var current: String?
    private(set) var backgroundsStateURL: URL = Paths.themesDirectory.appending(path: ".backgrounds.json")

    private let backend: StackBackend
    private let log: CommandLog

    init(backend: StackBackend, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    /// Writes a theme.json for any theme that lacks one, derived from its
    /// existing theme.env. Idempotent and additive — the env file is left
    /// exactly as it is, so theme-switch and bordersrc are unaffected.
    @discardableResult
    func migrateToManifests() -> [String] {
        let fm = FileManager.default
        let root = Paths.themesDirectory
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        var migrated: [String] = []

        for url in entries where !url.lastPathComponent.hasPrefix(".") {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            guard ThemeManifest.load(from: url) == nil else { continue }

            let env = Self.parseEnv(url.appending(path: "theme.env"))
            guard !env.isEmpty else { continue }

            var manifest = ThemeManifest.from(env: env, name: url.lastPathComponent)
            if fm.fileExists(atPath: url.appending(path: "ghostty.conf").path) {
                manifest.apps.ghosttyConfig = "ghostty.conf"
            }
            do {
                try manifest.write(to: url)
                migrated.append(manifest.name)
            } catch {
                log.note("manifest write failed", "\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !migrated.isEmpty {
            log.note("generated theme.json", migrated.joined(separator: ", "))
        }
        return migrated
    }

    func reload() {
        migrateToManifests()
        let root = Paths.themesDirectory
        let fm = FileManager.default

        current = try? String(contentsOf: root.appending(path: ".current"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let chosen = Self.parseBackgroundsState(backgroundsStateURL)

        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        themes = entries
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                Theme(name: url.lastPathComponent,
                      directory: url,
                      values: Self.parseEnv(url.appending(path: "theme.env")),
                      selectedBackground: chosen[url.lastPathComponent],
                      manifest: ThemeManifest.load(from: url))
            }

        log.note("loaded themes", "\(themes.count) in ~/.config/themes")
    }

    /// Writes the manifest, then regenerates the legacy env file from it so the
    /// shell pipeline stays in step. JSON is the source; env is the output.
    func save(_ manifest: ThemeManifest, to directory: URL) throws {
        try manifest.write(to: directory)
        try manifest.envRepresentation()
            .write(to: directory.appending(path: "theme.env"), atomically: true, encoding: .utf8)
        log.note("saved \(manifest.name)", "theme.json + regenerated theme.env")
        reload()
    }

    /// Copies a theme folder in. Requires a manifest — an imported theme must be
    /// data, never shell that gets sourced at login.
    @discardableResult
    func importTheme(from source: URL) throws -> String {
        guard let manifest = ThemeManifest.load(from: source) else {
            throw ThemeError.notAPackage
        }
        let name = manifest.name.isEmpty ? source.lastPathComponent : manifest.name
        let destination = Paths.themesDirectory.appending(path: name)

        if FileManager.default.fileExists(atPath: destination.path) {
            throw ThemeError.alreadyInstalled(name)
        }
        try FileManager.default.copyItem(at: source, to: destination)

        // Anything executable or shell-shaped has no business in a theme.
        for stray in ["theme.env", "install.sh", "postinstall.sh"] {
            try? FileManager.default.removeItem(at: destination.appending(path: stray))
        }
        try manifest.envRepresentation()
            .write(to: destination.appending(path: "theme.env"), atomically: true, encoding: .utf8)

        log.note("imported \(name)", "from \(source.lastPathComponent)")
        reload()
        return name
    }

    func exportTheme(_ theme: Theme, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: theme.directory, to: destination)
        // The env file is generated, so it does not travel with the package.
        try? fm.removeItem(at: destination.appending(path: "theme.env"))
        log.note("exported \(theme.name)", destination.lastPathComponent)
    }

    /// Themes shipped inside the app bundle, used as the reset baseline.
    static func bundledDefault(named name: String) -> ThemeManifest? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return ThemeManifest.load(from: resources.appending(path: "Defaults/themes/\(name)"))
    }

    func hasDefault(_ theme: Theme) -> Bool { Self.bundledDefault(named: theme.name) != nil }

    func isModified(_ theme: Theme) -> Bool {
        guard let original = Self.bundledDefault(named: theme.name),
              let current = theme.manifest else { return false }
        return original != current
    }

    func resetToDefault(_ theme: Theme) throws {
        guard let original = Self.bundledDefault(named: theme.name) else {
            throw ThemeError.noDefault(theme.name)
        }
        try save(original, to: theme.directory)
        log.note("reset \(theme.name)", "restored shipped default")
    }

    func apply(_ theme: Theme) async {
        let result = await backend.applyTheme(named: theme.name)
        log.record(result)
        if result.ok { current = theme.name }
    }

    nonisolated static func parseBackgroundsState(_ url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    /// KEY=value / KEY="value", skipping comments and blanks.
    nonisolated static func parseEnv(_ url: URL) -> [String: String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var values: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                  let split = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<split])
            var value = String(line[line.index(after: split)...])
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }
        return values
    }
}

extension Color {
    /// Alpha channel of a `0xAARRGGBB` value, so a fully transparent border can
    /// be reported as "not drawn" rather than silently rendering as nothing.
    static func macarchyAlpha(_ raw: String?) -> Double? {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        guard text.count == 8, let value = UInt64(text, radix: 16) else { return 1 }
        return Double((value >> 24) & 0xFF) / 255
    }

    /// Parses the `0xAARRGGBB` form that borders and sketchybar both use,
    /// and the plain `#RRGGBB` used for FIREFOX_ACCENT.
    init?(macarchyHex raw: String?) {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        if text.hasPrefix("#") { text = String(text.dropFirst()) }
        guard let value = UInt64(text, radix: 16) else { return nil }

        let a, r, g, b: Double
        switch text.count {
        case 8:
            a = Double((value >> 24) & 0xFF) / 255
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        case 6:
            a = 1
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
