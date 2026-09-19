import Foundation
import Desktop
import Observation
import SwiftUI
import AppKit

/// Reads ~/.config/themes. Each theme is a directory holding a `theme.env` of
/// plain KEY="value" lines, which is why no shell parsing is needed here.
@MainActor
@Observable
final class ThemeCatalog {
    private(set) var themes: [InstalledTheme] = []
    private(set) var current: String?
    private(set) var backgroundsStateURL: URL = Paths.themesDirectory.appending(
        path: ".backgrounds.json")

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
        let entries =
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))
            ?? []
        var migrated: [String] = []

        for url in entries where !url.lastPathComponent.hasPrefix(".") {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            guard Theme.load(from: url) == nil else { continue }

            let env = EnvFile.parse(url.appending(path: "theme.env"))
            guard !env.isEmpty else { continue }

            var manifest = Theme.from(env: env, name: url.lastPathComponent)
            if fm.fileExists(atPath: url.appending(path: "ghostty.conf").path) {
                manifest.apps.ghosttyConfig = "ghostty.conf"
            }
            do {
                try manifest.write(to: url)
                migrated.append(manifest.name)
            } catch {
                log.note(
                    "manifest write failed",
                    "\(url.lastPathComponent): \(error.localizedDescription)")
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

        let entries =
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))
            ?? []
        themes =
            entries
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                InstalledTheme(
                    name: url.lastPathComponent,
                    directory: url,
                    values: EnvFile.parse(url.appending(path: "theme.env")),
                    selectedBackground: chosen[url.lastPathComponent],
                    manifest: Theme.load(from: url),
                    palette: GhosttyPalette.load(from: url))
            }

        log.note("loaded themes", "\(themes.count) in ~/.config/themes")
    }

    /// Writes the manifest, then regenerates the legacy env file from it so the
    /// shell pipeline stays in step. JSON is the source; env is the output.
    func save(_ manifest: Theme, to directory: URL) throws {
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
        guard let manifest = Theme.load(from: source) else {
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

    func exportTheme(_ theme: InstalledTheme, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: theme.directory, to: destination)
        // The env file is generated, so it does not travel with the package.
        try? fm.removeItem(at: destination.appending(path: "theme.env"))
        log.note("exported \(theme.name)", destination.lastPathComponent)
    }

    /// Themes shipped inside the app bundle, used as the reset baseline.
    static func bundledDefault(named name: String) -> Theme? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return Theme.load(from: resources.appending(path: "Themes/\(name)"))
    }

    func hasDefault(_ theme: InstalledTheme) -> Bool { Self.bundledDefault(named: theme.name) != nil }

    func isModified(_ theme: InstalledTheme) -> Bool {
        guard let original = Self.bundledDefault(named: theme.name),
            let current = theme.manifest
        else { return false }
        return original != current
    }

    func resetToDefault(_ theme: InstalledTheme) throws {
        guard let original = Self.bundledDefault(named: theme.name) else {
            throw ThemeError.noDefault(theme.name)
        }
        try save(original, to: theme.directory)
        log.note("reset \(theme.name)", "restored shipped default")
    }

    func apply(_ theme: InstalledTheme) async {
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

}
