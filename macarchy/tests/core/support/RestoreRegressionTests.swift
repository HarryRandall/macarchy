import Foundation
import Testing
@testable import Macarchy

struct RestoreRegressionTests {
    @Test func oldestSnapshotSurvivesRestoreAtRetentionLimit() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-restore-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "settings.json")
        let store = SnapshotStore(root: root.appending(path: "snapshots"), keep: 1)
        try "old".write(to: file, atomically: true, encoding: .utf8)
        let snapshot = try #require(try store.capture([file], reason: "before"))
        try "new".write(to: file, atomically: true, encoding: .utf8)
        try store.restore(snapshot)
        #expect(try String(contentsOf: file, encoding: .utf8) == "old")
        let undo = try #require(store.list().first)
        try store.restore(undo)
        #expect(try String(contentsOf: file, encoding: .utf8) == "new")
    }
}
