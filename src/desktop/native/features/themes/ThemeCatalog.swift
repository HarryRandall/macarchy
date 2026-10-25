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
    private let read: @Sendable () throws -> ThemeCollection.Snapshot
    /// Counts reads as they start, so a background read that finishes after
    /// a newer one never publishes its older result over it.
    private var reads = 0
    private var published = 0

    init(
        backend: Integrations, log: CommandLog,
        read: @escaping @Sendable () throws -> ThemeCollection.Snapshot = {
            try ThemeCollection().read()
        }
    ) {
        self.backend = backend
        self.log = log
        self.read = read
    }

    func reload() {
        do { try refresh() } catch { report(error) }
    }

    /// `reload`, with settings and every theme folder read off the main
    /// thread. The switcher uses it, so opening and applying never wait on
    /// the disk with the main thread held.
    func reloadInBackground() async {
        reads += 1
        let started = reads
        let read = self.read
        let outcome = await Task.detached(priority: .userInitiated) { Result { try read() } }.value
        guard started > published else { return }
        published = started
        switch outcome {
        case .success(let snapshot): publish(snapshot)
        case .failure(let error): report(error)
        }
    }

    private func report(_ error: any Error) {
        let message = error.localizedDescription
        if lastError != message { lastError = message }
        log.failure("Settings unreadable", error.localizedDescription)
    }

    /// A throwing read lets a first page load report failure instead of stale defaults.
    /// Pages read through here, and every assignment notifies `StateBroadcast` even when
    /// the value is the same, so properties are set only when they change.
    func refresh() throws {
        reads += 1
        published = reads
        publish(try read())
    }

    private func publish(_ snapshot: ThemeCollection.Snapshot) {
        if current != snapshot.current { current = snapshot.current }
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
        if themes != next { themes = next }
        if warnings != snapshot.warnings { warnings = snapshot.warnings }
        for warning in snapshot.warnings { log.note("Invalid theme", warning) }
        if lastError != nil { lastError = nil }

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
        if lastError != nil { lastError = nil }
        defer { isApplying = false }
        let result = await backend.applyTheme(named: theme.name)
        log.record(result)
        if result.ok {
            reload()
        } else if lastError != result.summary {
            lastError = result.summary
        }
    }

}
