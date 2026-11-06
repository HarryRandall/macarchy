import Foundation
import Synchronization
import Testing

@testable import Macarchy

/// Snapshots are the safety net every migration phase is gated on, so these
/// cover the two bugs the original implementation actually shipped with:
/// second-resolution ids that collided under debounced writes, and a restore
/// that destroyed the snapshot it was reading from.
@Suite("SnapshotStore")
struct SnapshotStoreTests {
    private func sandbox() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-snap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("restores the captured contents, not the current ones")
    func restoreReturnsCapturedContent() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 5)

        try "VERSION=1\n".write(to: target, atomically: true, encoding: .utf8)
        let first = try #require(try store.capture([target], reason: "v1"))

        try "VERSION=2\n".write(to: target, atomically: true, encoding: .utf8)
        try store.restore(first)

        #expect(try String(contentsOf: target, encoding: .utf8) == "VERSION=1\n")
    }

    @Test("restoring is itself undoable")
    func restoreSnapshotsCurrentState() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 5)

        try "VERSION=1\n".write(to: target, atomically: true, encoding: .utf8)
        let first = try #require(try store.capture([target], reason: "v1"))
        try "VERSION=2\n".write(to: target, atomically: true, encoding: .utf8)
        try store.restore(first)

        #expect(store.list().count >= 2)
    }

    /// Writes debounce ~100ms apart, so ids must not collide within a second.
    @Test("rapid captures get distinct ids")
    func rapidCapturesDoNotCollide() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 50)

        var ids = Set<String>()
        for index in 0..<8 {
            try "VERSION=\(index)\n".write(to: target, atomically: true, encoding: .utf8)
            let snapshot = try #require(try store.capture([target], reason: "v\(index)"))
            ids.insert(snapshot.id)
        }
        #expect(ids.count == 8)
    }

    @Test("pruning keeps exactly the limit")
    func pruningHonoursTheLimit() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 3)

        for index in 0..<10 {
            try "VERSION=\(index)\n".write(to: target, atomically: true, encoding: .utf8)
            _ = try store.capture([target], reason: "v\(index)")
        }
        #expect(store.list().count == 3)
    }

    /// `macarchy restore <id>` suggests `restore <id> --apply` next, so the
    /// snapshot it restored must outlast the prune its own restore triggers.
    @Test("restoring the oldest snapshot at the limit keeps it for a second restore")
    func restoredSnapshotSurvivesItsOwnPrune() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 3)
        var captured: [SnapshotStore.Snapshot] = []
        for index in 0..<3 {
            try "VERSION=\(index)\n".write(to: target, atomically: true, encoding: .utf8)
            captured.append(try #require(try store.capture([target], reason: "v\(index)")))
        }
        try "VERSION=3\n".write(to: target, atomically: true, encoding: .utf8)
        let oldest = try #require(captured.first)
        #expect(store.list().last?.id == oldest.id)

        try store.restore(oldest)
        let afterFirst = store.list()
        #expect(afterFirst.contains { $0.id == oldest.id })
        #expect(
            store.reason(for: try #require(afterFirst.first)) == "before restoring \(oldest.id)")

        let again = try #require(afterFirst.first { $0.id == oldest.id })
        try store.restore(again)
        #expect(try String(contentsOf: target, encoding: .utf8) == "VERSION=0\n")

        // The spared snapshot goes at the next ordinary capture.
        _ = try store.capture([target], reason: "later")
        #expect(store.list().count == 3)
        #expect(!store.list().contains { $0.id == oldest.id })
    }

    /// Captures run under different locks, or none, so the app and CLI can
    /// prune the same oldest snapshot at once. That must not fail either write.
    @Test("concurrent captures prune without failing each other")
    func concurrentPruning() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "settings.env")
        try "VERSION=1\n".write(to: target, atomically: true, encoding: .utf8)
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 2)
        let failures = Mutex(0)
        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            do { try store.capture([target], reason: "concurrent") } catch {
                failures.withLock { $0 += 1 }
            }
        }
        #expect(failures.withLock { $0 } == 0)
        #expect(store.list().count == 2)
    }

    @Test("a capture of only missing files is a no-op, not a failure")
    func missingFilesAreSkipped() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 3)
        #expect(try store.capture([root.appending(path: "nope.env")], reason: "none") == nil)
    }
}
