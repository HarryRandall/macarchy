import Foundation
import Testing

@testable import Macarchy

/// Which skhdrc the Shortcuts page edits, and how a linked one is written
/// and restored. Everything runs in a temporary home and snapshot store.
struct SkhdFileTests {
    private struct Files {
        let root: URL
        let config: URL
        let snapshots: SnapshotStore
    }

    private func temporary() throws -> Files {
        let root = FileManager.default.temporaryDirectory.appending(path: "skhd-file-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Files(
            root: root, config: root.appending(path: "skhdrc"),
            snapshots: SnapshotStore(root: root.appending(path: "snapshots")))
    }

    private func shortcuts(
        _ config: URL, _ snapshots: SnapshotStore, defaults: URL? = nil
    ) -> SkhdShortcuts {
        SkhdShortcuts(
            integrations: Integrations { _, _ in
                CommandResult(command: "fake", status: 1, stderr: "Restart refused")
            }, config: config, snapshots: snapshots, defaultsURL: defaults)
    }

    /// skhd runs from Macarchy's agent with `-c`, so the file it reads, and
    /// the one the Shortcuts page edits, is Macarchy's copy; the person's own
    /// `~/.config/skhd/skhdrc` or `~/.skhdrc` is only read once, by setup.
    @Test("the shortcuts file is Macarchy's config, not skhd's default places")
    func location() {
        #expect(Paths.skhdrc == Paths.configDirectory.appending(path: "skhdrc"))
        #expect(Setup.skhdrc == Paths.skhdrc)
        #expect(SkhdShortcuts().configURL == Paths.skhdrc.resolvingSymlinksInPath())
    }

    /// The edit snapshots the link's target, so restoring it must write the
    /// target back, leave the link a link and restart skhd whatever the
    /// target is called.
    @Test("a snapshot of a linked skhdrc restores through the link and restarts skhd")
    func restoreLinked() async throws {
        let files = try temporary()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let fm = FileManager.default
        let target = files.root.appending(path: "dotfiles/skhd-shortcuts")
        try fm.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cmd - a : echo one\n".write(to: target, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: files.config, withDestinationURL: target)
        let shortcuts = shortcuts(files.config, files.snapshots)
        _ = try await shortcuts.rebind(
            id: 0, revision: shortcuts.read().revision, chord: .init(modifiers: ["alt"], key: "a"))
        #expect(try String(contentsOf: target, encoding: .utf8) == "alt - a : echo one\n")

        let snapshot = try #require(files.snapshots.list().first)
        let paths = files.snapshots.originalPaths(of: snapshot)
        #expect(paths == [shortcuts.configURL.path])
        #expect(DesktopConfiguration.touchesShortcuts(paths, linked: shortcuts.configURL.path))
        #expect(!DesktopConfiguration.touchesShortcuts(paths, linked: "/elsewhere"))
        try files.snapshots.restore(snapshot)
        #expect(try fm.destinationOfSymbolicLink(atPath: files.config.path) == target.path)
        #expect(try String(contentsOf: target, encoding: .utf8) == "cmd - a : echo one\n")
    }
}
