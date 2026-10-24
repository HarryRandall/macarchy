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

    @Test("skhd's own order picks the file: the config folder, then a lone dotfile")
    func location() throws {
        let files = try temporary()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let home = files.root
        let primary = home.appending(path: ".config/skhd/skhdrc")
        let dotfile = home.appending(path: ".skhdrc")
        #expect(Paths.skhdrc(home: home) == primary)
        try "cmd - j : echo dotfile\n".write(to: dotfile, atomically: true, encoding: .utf8)
        #expect(Paths.skhdrc(home: home) == dotfile)
        try FileManager.default.createDirectory(
            at: primary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cmd - j : echo primary\n".write(to: primary, atomically: true, encoding: .utf8)
        #expect(Paths.skhdrc(home: home) == primary)
    }

    /// With a lone `~/.skhdrc`, Reset must snapshot that file, the person's
    /// only copy, and replace it in place rather than seed a second file.
    @Test("reset snapshots a lone dotfile before replacing it")
    func resetDotfile() async throws {
        let files = try temporary()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let home = files.root
        let dotfile = home.appending(path: ".skhdrc")
        try "cmd - j : echo my-only-copy\n".write(to: dotfile, atomically: true, encoding: .utf8)
        let defaults = home.appending(path: "defaults")
        try "play : echo default\n".write(to: defaults, atomically: true, encoding: .utf8)
        let shortcuts = shortcuts(
            Paths.skhdrc(home: home), files.snapshots, defaults: defaults)
        let state = try shortcuts.read()
        #expect(state.bindings.map(\.key) == ["j"])
        _ = try await shortcuts.reset(revision: state.revision)
        #expect(try String(contentsOf: dotfile, encoding: .utf8) == "play : echo default\n")
        let snapshot = try #require(files.snapshots.list().first)
        #expect(
            try String(contentsOf: snapshot.url.appending(path: "0-.skhdrc"), encoding: .utf8)
                == "cmd - j : echo my-only-copy\n")
        #expect(
            !FileManager.default.fileExists(
                atPath: home.appending(path: ".config/skhd/skhdrc").path))
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
