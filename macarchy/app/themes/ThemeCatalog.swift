import Foundation
import Macarchy
import Observation
import SwiftUI
import AppKit

/// Presents validated theme manifests and saved selections to the app.
@MainActor
@Observable
final class ThemeCatalog {
    private(set) var themes: [InstalledTheme] = []
    private(set) var current: String?
    private(set) var isApplying = false
    private(set) var lastError: String?
    private let backend: Integrations
    private let log: CommandLog

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    func reload() {
        let root = Paths.themesDirectory
        let fm = FileManager.default

        let settings: SettingsDocument
        do { settings = try SettingsStore().read() } catch {
            log.note("Settings unreadable", error.localizedDescription); return
        }
        current = settings.currentTheme
        let chosen = settings.wallpapers

        let entries =
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))
            ?? []
        themes =
            entries
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url -> InstalledTheme? in
                let manifest: Theme
                do { manifest = try Theme.read(from: url) } catch {
                    log.note(
                        "Invalid theme", "\(url.lastPathComponent): \(error.localizedDescription)")
                    return nil
                }
                return InstalledTheme(
                    name: url.lastPathComponent,
                    directory: url,
                    selectedBackground: chosen[url.lastPathComponent],
                    manifest: manifest,
                    palette: GhosttyPalette.load(from: url))
            }

        log.note("loaded themes", "\(themes.count) in ~/.config/themes")
    }

    /// Saves the theme definition; compatibility outputs are refreshed when applied.
    func save(_ manifest: Theme, to directory: URL) throws {
        try ThemeLibrary().save(manifest, to: directory)
        reload()
    }

    @discardableResult
    func importTheme(from source: URL) throws -> String {
        let name = try ThemeLibrary().importTheme(from: source)
        reload()
        return name
    }

    func exportTheme(_ theme: InstalledTheme, to destination: URL) throws {
        try ThemeLibrary().exportTheme(from: theme.directory, to: destination)
    }

    /// Themes shipped inside the app bundle, used as the reset baseline.
    static func bundledDefault(named name: String) -> Theme? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return Theme.load(from: resources.appending(path: "Themes/\(name)"))
    }

    func hasDefault(_ theme: InstalledTheme) -> Bool {
        Self.bundledDefault(named: theme.name) != nil
    }

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
        isApplying = true
        lastError = nil
        defer { isApplying = false }
        let result = await backend.applyTheme(named: theme.name)
        log.record(result)
        if result.ok { reload() } else { lastError = result.summary }
    }

}
