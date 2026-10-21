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
    private(set) var revision = 0
    private(set) var warnings: [String] = []
    private let backend: Integrations
    private let log: CommandLog

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    func reload() {
        do { try refresh() } catch {
            lastError = error.localizedDescription
            log.failure("Settings unreadable", error.localizedDescription)
        }
    }

    /// A throwing read lets a first page load report failure instead of stale defaults.
    func refresh() throws {
        let snapshot = try ThemeCollection().read()
        current = snapshot.current
        let next = snapshot.themes.map {
            InstalledTheme(
                name: $0.name, directory: $0.directory,
                selectedBackground: snapshot.wallpapers[$0.name], manifest: $0.manifest,
                terminal: $0.terminal)
        }
        if themes.map(\.manifest) != next.map(\.manifest)
            || themes.map(\.selectedBackground) != next.map(\.selectedBackground)
            || themes.map(\.terminal) != next.map(\.terminal)
        {
            revision += 1
        }
        themes = next
        warnings = snapshot.warnings
        for warning in snapshot.warnings { log.note("Invalid theme", warning) }
        lastError = nil

        log.note("loaded themes", "\(themes.count) in \(Paths.display(Paths.themesDirectory))")
    }

    /// Saves the theme definition; compatibility outputs are refreshed when applied.
    func save(_ manifest: Theme, to directory: URL) throws {
        try ThemeLibrary().save(manifest, to: directory)
        reload()
    }

    /// Themes shipped inside the app bundle, used as the reset baseline.
    static func bundledDefault(named name: String) -> Theme? {
        ThemeCollection().bundledDefault(named: name)
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

    func apply(_ theme: InstalledTheme) async {
        isApplying = true
        lastError = nil
        defer { isApplying = false }
        let result = await backend.applyTheme(named: theme.name)
        log.record(result)
        if result.ok { reload() } else { lastError = result.summary }
    }

}
