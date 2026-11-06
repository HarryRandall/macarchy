import Foundation
import Observation
import Testing

@testable import App
@testable import Macarchy

/// `onChange` is `@Sendable`, so the count is guarded rather than captured as a variable.
private final class Changes: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func record() { lock.withLock { count += 1 } }
    var recorded: Int { lock.withLock { count } }
}

/// Holds the second read of the theme folders until the test lets it go, so a
/// background read can be made to finish after a newer one.
private final class HeldRead: @unchecked Sendable {
    private let condition = NSCondition()
    private var reads = 0
    private var released = false
    private var arrived: CheckedContinuation<Void, Never>?

    /// The snapshot for each read: the held one sees the folders as they were.
    func read() -> ThemeCollection.Snapshot {
        condition.lock()
        reads += 1
        let number = reads
        if number == 2 {
            arrived?.resume()
            arrived = nil
            while !released { condition.wait() }
        }
        condition.unlock()
        return ThemeCollection.Snapshot(
            themes: [], current: number == 3 ? "newer" : "older", wallpapers: [:], warnings: [])
    }

    func untilHeld() async {
        await withCheckedContinuation { continuation in
            condition.lock()
            if reads >= 2 { continuation.resume() } else { arrived = continuation }
            condition.unlock()
        }
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
}

@MainActor
struct ThemeCatalogTests {
    private func temporary() throws -> (URL, ThemeCatalog) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: "theme-catalog-\(UUID())")
        let themes = root.appending(path: "themes")
        try fm.createDirectory(at: themes, withIntermediateDirectories: true)
        try fm.copyItem(
            at: repository.appending(path: "resources/themes/lumon"),
            to: themes.appending(path: "lumon"))
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update { $0.currentTheme = "lumon" }
        let catalog = ThemeCatalog(
            backend: Integrations { _, _ in
                Issue.record("Reading themes must not reach the desktop")
                return CommandResult(command: "fake", status: 1)
            },
            log: CommandLog(),
            read: { try ThemeCollection(root: themes, resources: nil).read(store: store) })
        return (root, catalog)
    }

    /// Tracks what `StateBroadcast` tracks, plus the other values a refresh sets.
    private func changes(_ catalog: ThemeCatalog, during body: () throws -> Void) rethrows -> Int {
        let changes = Changes()
        withObservationTracking {
            _ = catalog.themes
            _ = catalog.current
            _ = catalog.revision
            _ = catalog.warnings
            _ = catalog.lastError
        } onChange: {
            changes.record()
        }
        try body()
        return changes.recorded
    }

    @Test("refreshing unchanged theme files fires no observation")
    func unchangedRefresh() throws {
        let (root, catalog) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try catalog.refresh()
        #expect(catalog.themes.map(\.name) == ["lumon"])
        #expect(catalog.current == "lumon")
        let revision = catalog.revision
        #expect(try changes(catalog) { try catalog.refresh() } == 0)
        #expect(catalog.revision == revision)
    }

    @Test("refreshing after a manifest edit fires observation and bumps the revision")
    func changedManifest() throws {
        let (root, catalog) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try catalog.refresh()
        let revision = catalog.revision
        let directory = root.appending(path: "themes/lumon")
        var manifest = try Theme.read(from: directory)
        manifest.dark.toggle()
        try manifest.write(to: directory)
        #expect(try changes(catalog) { try catalog.refresh() } == 1)
        #expect(catalog.revision == revision + 1)
        #expect(catalog.themes.first?.manifest?.dark == manifest.dark)
    }

    @Test("a background read that finishes after a newer read is dropped")
    func lateBackgroundRead() async throws {
        let held = HeldRead()
        let catalog = ThemeCatalog(
            backend: Integrations { _, _ in CommandResult(command: "fake", status: 1) },
            log: CommandLog(), read: { held.read() })
        try catalog.refresh()
        #expect(catalog.current == "older")
        let late = Task { await catalog.reloadInBackground() }
        await held.untilHeld()
        try catalog.refresh()
        #expect(catalog.current == "newer")
        held.release()
        await late.value
        #expect(catalog.current == "newer")
    }

    @Test("a background read publishes what it finds")
    func backgroundRead() async throws {
        let (root, catalog) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(catalog.themes.isEmpty)
        await catalog.reloadInBackground()
        #expect(catalog.themes.map(\.name) == ["lumon"])
        #expect(catalog.current == "lumon")
    }
}
