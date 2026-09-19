import Foundation
import Testing

@testable import Kit

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

    @Test("a capture of only missing files is a no-op, not a failure")
    func missingFilesAreSkipped() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 3)
        #expect(try store.capture([root.appending(path: "nope.env")], reason: "none") == nil)
    }
}
