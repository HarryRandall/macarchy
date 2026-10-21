import Foundation
import Testing

@testable import Macarchy

private struct ShortcutFiles {
    let root: URL
    let config: URL
    let snapshots: SnapshotStore
}

struct SkhdShortcutsTests {
    private func fixture() throws -> ShortcutFiles {
        let root = FileManager.default.temporaryDirectory.appending(path: "shortcuts-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ShortcutFiles(
            root: root, config: root.appending(path: "skhdrc"),
            snapshots: SnapshotStore(root: root.appending(path: "snapshots")))
    }

    private func operation(
        _ config: URL, _ snapshots: SnapshotStore, defaults: URL? = nil
    ) -> SkhdShortcuts {
        SkhdShortcuts(
            integrations: Integrations { _, _ in
                CommandResult(command: "fake", status: 1, stderr: "Restart refused")
            }, config: config, snapshots: snapshots, defaultsURL: defaults)
    }

    @Test("missing and unreadable configuration fail without seeding anything")
    func missingRead() throws {
        let files = try fixture()
        let (root, config) = (files.root, files.config)
        let snapshots = files.snapshots
        defer { try? FileManager.default.removeItem(at: root) }
        let shortcuts = operation(config, snapshots)
        #expect(throws: (any Error).self) { try shortcuts.read() }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        try Data([0xff, 0xfe]).write(to: config)
        #expect(throws: (any Error).self) { try shortcuts.read() }
        #expect(snapshots.list().isEmpty)
    }

    @Test("reading is read-only; rebind preserves custom lines, comments, blocks and permissions")
    func preservingRebind() async throws {
        let files = try fixture()
        let (root, config) = (files.root, files.config)
        let snapshots = files.snapshots
        defer { try? FileManager.default.removeItem(at: root) }
        let shortcuts = operation(config, snapshots)
        let text =
            "# Mine\nctrl - h -> [\n  \"Finder\" : echo 'a -> b: c'\n  * : echo fallback\n]\n\n.load other.conf\ncmd - t : echo untouched\n"
        try text.write(to: config, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: config.path)
        let state = try shortcuts.read()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["skhdrc"])
        #expect(snapshots.list().isEmpty)
        let result = try await shortcuts.rebind(
            id: 1, revision: state.revision, chord: .init(modifiers: ["cmd", "shift"], key: "k"))
        #expect(
            try String(contentsOf: config, encoding: .utf8)
                == text.replacingOccurrences(of: "ctrl - h", with: "shift + cmd - k"))
        if Paths.isInstalled("skhd") {
            #expect(!result.ok)
            #expect(result.stderr.contains("Shortcuts were saved, but skhd could not restart"))
        } else {
            #expect(result.ok)
            #expect(result.stdout.contains("skhd is not installed"))
        }
        let snapshot = try #require(snapshots.list().first)
        #expect(
            try String(contentsOf: snapshot.url.appending(path: "0-skhdrc"), encoding: .utf8)
                == text)
        #expect(
            try FileManager.default.attributesOfItem(atPath: config.path)[.posixPermissions] as? Int
                == 0o640)
    }

    @Test("stale revisions, duplicate chords and injection are refused before snapshot or write")
    func refusedEdits() async throws {
        let files = try fixture()
        let (root, config) = (files.root, files.config)
        let snapshots = files.snapshots
        defer { try? FileManager.default.removeItem(at: root) }
        let shortcuts = operation(config, snapshots)
        let text = "ctrl - h : echo first\ncmd - k : echo second\n"
        try text.write(to: config, atomically: true, encoding: .utf8)
        let state = try shortcuts.read()
        for chord in [
            ShortcutChord(modifiers: ["cmd"], key: "k"),
            .init(modifiers: ["cmd"], key: "k : echo injected"),
            .init(modifiers: ["ctrl\n.load evil"], key: "k")
        ] {
            await #expect(throws: (any Error).self) {
                try await shortcuts.rebind(id: 0, revision: state.revision, chord: chord)
            }
        }
        let external = text + "# changed elsewhere\n"
        try external.write(to: config, atomically: true, encoding: .utf8)
        await #expect(throws: (any Error).self) {
            try await shortcuts.disable(id: 0, revision: state.revision)
        }
        #expect(try String(contentsOf: config, encoding: .utf8) == external)
        #expect(snapshots.list().isEmpty)
    }

    @Test("disable comments out the whole block; symlinks retain their target")
    func disableBlock() async throws {
        let files = try fixture()
        let (root, config) = (files.root, files.config)
        let snapshots = files.snapshots
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appending(path: "personal-shortcuts")
        let text =
            "alt - p [\n\"Finder\" : echo finder\n* : echo other\n]\ncmd - t : echo untouched\n"
        try text.write(to: target, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: config, withDestinationURL: target)
        let shortcuts = operation(config, snapshots)
        _ = try await shortcuts.disable(id: 0, revision: shortcuts.read().revision)
        #expect(
            try FileManager.default.destinationOfSymbolicLink(atPath: config.path) == target.path)
        #expect(try shortcuts.read().bindings.count == 1)
        #expect(
            try String(contentsOf: target, encoding: .utf8).hasPrefix("# alt - p [\n# \"Finder\""))
    }

    @Test("only an explicit reset installs defaults, after snapshotting the custom file")
    func reset() async throws {
        let files = try fixture()
        let (root, config) = (files.root, files.config)
        let snapshots = files.snapshots
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = root.appending(path: "defaults")
        try "ctrl - return : echo default\n".write(to: defaults, atomically: true, encoding: .utf8)
        try "cmd - p : echo custom\n".write(to: config, atomically: true, encoding: .utf8)
        let shortcuts = operation(config, snapshots, defaults: defaults)
        let state = try shortcuts.read()
        #expect(state.bindings.first?.command == "echo custom")
        _ = try await shortcuts.reset(revision: state.revision)
        #expect(try shortcuts.read().bindings.first?.command == "echo default")
        #expect(snapshots.list().count == 1)
        await #expect(throws: (any Error).self) {
            try await shortcuts.reset(revision: state.revision)
        }
    }

    @Test("a failed snapshot leaves the person's configuration untouched")
    func snapshotFailure() async throws {
        let files = try fixture()
        defer { try? FileManager.default.removeItem(at: files.root) }
        let text = "cmd - h : echo personal\n"
        try text.write(to: files.config, atomically: true, encoding: .utf8)
        try "not a directory".write(to: files.snapshots.root, atomically: true, encoding: .utf8)
        let shortcuts = operation(files.config, files.snapshots)
        await #expect(throws: (any Error).self) {
            try await shortcuts.rebind(
                id: 0, revision: shortcuts.read().revision,
                chord: .init(modifiers: ["cmd"], key: "k"))
        }
        #expect(try String(contentsOf: files.config, encoding: .utf8) == text)
    }

    @Test("validation renders skhd notation and detects aliases and physical keycodes")
    func validation() throws {
        let chord = try ShortcutChord(modifiers: ["cmd", "shift"], key: "K").validated()
        #expect(chord.keySpec == "shift + cmd - k")
        #expect(chord.caps == ["⇧", "⌘", "K"])
        let binding = try #require(SkhdConfig.parse("hyper - 0x24 : echo conflict").first)
        #expect(
            ShortcutChord(modifiers: ["ctrl", "alt", "shift", "cmd"], key: "return").overlaps(
                binding))
        #expect(throws: (any Error).self) {
            try ShortcutChord(modifiers: [], key: "\n").validated()
        }
        #expect(throws: (any Error).self) {
            try ShortcutChord(modifiers: ["cmd"], key: "k\n").validated()
        }
        let rawLetter = try #require(SkhdConfig.parse("cmd - 0x28 : echo conflict").first)
        #expect(ShortcutChord(modifiers: ["cmd"], key: "k").overlaps(rawLetter))
        #expect(throws: (any Error).self) {
            try ShortcutChord(modifiers: [], key: "0xff").validated()
        }
    }
}
