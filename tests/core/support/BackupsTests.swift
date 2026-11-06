import Foundation
import Testing

@testable import Macarchy

@Suite("Backups")
struct BackupsTests {
    /// A copy left by an interrupted save, with no manifest entry, used to
    /// block every later setup with "an item with the same name already exists".
    @Test("an orphaned copy does not block saving")
    func orphanedCopyDoesNotBlockSaving() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-backups-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "yabairc")
        try "mine".write(to: file, atomically: true, encoding: .utf8)
        let backups = Backups(root: root.appending(path: "backups"))
        try FileManager.default.createDirectory(at: backups.root, withIntermediateDirectories: true)
        let orphan = backups.root.appending(path: "0-yabairc")
        try "orphan".write(to: orphan, atomically: true, encoding: .utf8)
        try backups.save([file])
        #expect(backups.hasRecord(for: file))
        #expect(try String(contentsOf: orphan, encoding: .utf8) == "orphan")
        try "changed".write(to: file, atomically: true, encoding: .utf8)
        var report: [String] = []
        try backups.restoreAll(
            snapshots: SnapshotStore(root: root.appending(path: "snapshots")), into: &report)
        #expect(try String(contentsOf: file, encoding: .utf8) == "mine")
    }
}
