import Foundation
import Testing

@testable import Macarchy

/// Locations are passed in: the web view suites change `MACARCHY_HOME` for
/// the whole test process.
@Suite("Moving an earlier layout")
struct LegacyLayoutTests {
    private struct Home {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-legacy-\(UUID())")
        var legacy: URL { url.appending(path: ".config/macarchy") }
        var root: URL { url.appending(path: "Library/Application Support/Macarchy") }

        init() throws {
            try write("{\"currentTheme\":\"lumon\"}", "settings.json", in: legacy)
            try write("{}", "themes/lumon/theme.json", in: legacy)
            try write(
                "{\"reason\":\"settings changed\",\"paths\":{\"0-settings.json\":\""
                    + legacy.appending(path: "settings.json").path + "\"}}",
                "snapshots/one/.meta.json", in: legacy)
        }

        func write(_ text: String, _ path: String, in folder: URL) throws {
            let file = folder.appending(path: path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }

        func read(_ path: String, in folder: URL) -> String? {
            try? String(contentsOf: folder.appending(path: path), encoding: .utf8)
        }

        var setAside: [String] {
            let parent = root.deletingLastPathComponent()
            return ((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? [])
                .filter { $0.hasPrefix(LegacyLayout.setAsidePrefix) }
        }
    }

    @Test("the old folder moves whole and leaves a link")
    func moves() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        #expect(try LegacyLayout.move(legacy: home.legacy, root: home.root) == .moved)
        #expect(home.read("settings.json", in: home.root) == "{\"currentTheme\":\"lumon\"}")
        #expect(home.read("themes/lumon/theme.json", in: home.root) == "{}")
        let link = try FileManager.default.destinationOfSymbolicLink(atPath: home.legacy.path)
        #expect(link == home.root.path)
        #expect(try LegacyLayout.move(legacy: home.legacy, root: home.root) == .nothing)
    }

    @Test("a new folder made first is merged, not taken as already moved")
    func mergesEarlyFolder() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        try home.write("scratch", "state/bar/space_render", in: home.root)
        try home.write("early", "generated/extra", in: home.root)
        try home.write("old scratch", "state/bar/space_render", in: home.legacy)
        #expect(
            try LegacyLayout.move(legacy: home.legacy, root: home.root) == .merged(setAside: nil))
        #expect(home.read("settings.json", in: home.root) == "{\"currentTheme\":\"lumon\"}")
        #expect(home.read("generated/extra", in: home.root) == "early")
        #expect(home.read("state/bar/space_render", in: home.root) == "old scratch")
        #expect(home.setAside.isEmpty)
    }

    @Test("clashing files are kept aside")
    func keepsClashes() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        try home.write("{\"currentTheme\":\"lumon\"}", "theme-copy", in: home.legacy)
        try home.write("other", "theme-copy", in: home.root)
        let outcome = try LegacyLayout.move(legacy: home.legacy, root: home.root)
        guard case .merged(let aside?) = outcome else {
            Issue.record("expected a kept folder, got \(outcome)")
            return
        }
        #expect(home.read("theme-copy", in: aside) == "other")
        #expect(home.read("settings.json", in: home.root) == "{\"currentTheme\":\"lumon\"}")
    }

    @Test("the move leaves a note saying what it did")
    func notesTheMove() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        try home.write("other", "theme-copy", in: home.root)
        try home.write("mine", "theme-copy", in: home.legacy)
        try LegacyLayout.move(legacy: home.legacy, root: home.root)
        let note = try #require(LegacyLayout.Note.load(from: home.root))
        #expect(note.kind == .merged && note.from == home.legacy.path)
        #expect(note.setAside != nil)
        #expect(note.lines.count == 2)
        #expect(note.lines[0].hasPrefix("Moved "))
        #expect(note.lines[1].contains(LegacyLayout.setAsidePrefix))
    }

    @Test("a folder linked from dotfiles is copied, and the link and folder are left alone")
    func copiesLinkedFolder() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        let fm = FileManager.default
        let dotfiles = home.url.appending(path: "dotfiles/macarchy")
        try fm.createDirectory(
            at: dotfiles.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: home.legacy, to: dotfiles)
        try fm.createSymbolicLink(at: home.legacy, withDestinationURL: dotfiles)
        try home.write(
            "{\"reason\":\"x\",\"paths\":{\"0-settings.json\":\""
                + dotfiles.appending(path: "settings.json").path + "\"}}",
            "snapshots/two/.meta.json", in: dotfiles)
        #expect(LegacyLayout.needsMigration(legacy: home.legacy, root: home.root))
        let outcome = try LegacyLayout.move(legacy: home.legacy, root: home.root)
        guard case .copied(let source, nil) = outcome else {
            Issue.record("expected a copy, got \(outcome)")
            return
        }
        #expect(source.resolvingSymlinksInPath().path == dotfiles.resolvingSymlinksInPath().path)
        #expect(home.read("settings.json", in: home.root) == "{\"currentTheme\":\"lumon\"}")
        #expect(home.read("settings.json", in: dotfiles) == "{\"currentTheme\":\"lumon\"}")
        #expect(try fm.destinationOfSymbolicLink(atPath: home.legacy.path) == dotfiles.path)
        #expect(!LegacyLayout.needsMigration(legacy: home.legacy, root: home.root))
        #expect(LegacyLayout.hasLeftoverData(legacy: home.legacy, root: home.root))
        #expect(LegacyLayout.linkedFolder(legacy: home.legacy, root: home.root) != nil)
        let data = Data((home.read("snapshots/two/.meta.json", in: home.root) ?? "").utf8)
        let paths = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["paths"]
        #expect(
            (paths as? [String: String])?.values.first
                == home.root.appending(path: "settings.json").path)
        let note = try #require(LegacyLayout.Note.load(from: home.root))
        #expect(note.kind == .copied && note.lines[0].hasPrefix("Copied your settings from "))
        #expect(try LegacyLayout.move(legacy: home.legacy, root: home.root) == .nothing)
    }

    @Test("Macarchy's own link is never taken for an earlier folder")
    func ignoresOwnLink() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        let fm = FileManager.default
        try fm.removeItem(at: home.legacy)
        try home.write("{}", "themes/a/theme.json", in: home.root)
        try fm.createSymbolicLink(at: home.legacy, withDestinationURL: home.root)
        #expect(LegacyLayout.linkedFolder(legacy: home.legacy, root: home.root) == nil)
        #expect(!LegacyLayout.needsMigration(legacy: home.legacy, root: home.root))
        #expect(try LegacyLayout.move(legacy: home.legacy, root: home.root) == .nothing)
    }

    @Test("settings already in the new folder are never moved over")
    func leavesExistingSettings() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        try home.write("{}", "settings.json", in: home.root)
        #expect(!LegacyLayout.needsMigration(legacy: home.legacy, root: home.root))
        #expect(LegacyLayout.hasLeftoverData(legacy: home.legacy, root: home.root))
        #expect(try LegacyLayout.move(legacy: home.legacy, root: home.root) == .nothing)
        #expect(home.read("settings.json", in: home.root) == "{}")
    }

    @Test("an old folder without Macarchy's data is not moved")
    func ignoresEmptyFolder() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        for entry in LegacyLayout.dataEntries {
            try? FileManager.default.removeItem(at: home.legacy.appending(path: entry))
        }
        #expect(!LegacyLayout.needsMigration(legacy: home.legacy, root: home.root))
    }

    @Test("snapshot records follow the move")
    func relocatesSnapshots() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        try home.write(
            "{\"reason\":\"x\",\"paths\":{\"0-skhdrc\":\""
                + home.url.appending(path: ".config/skhd/skhdrc").path + "\"}}",
            "snapshots/two/.meta.json", in: home.legacy)
        try LegacyLayout.move(legacy: home.legacy, root: home.root)
        func paths(_ name: String) -> [String] {
            let data = Data((home.read("snapshots/\(name)", in: home.root) ?? "").utf8)
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return ((object?["paths"] as? [String: String]) ?? [:]).values.sorted()
        }
        #expect(paths("one/.meta.json") == [home.root.appending(path: "settings.json").path])
        #expect(
            paths("one/.meta.legacy.json") == [home.legacy.appending(path: "settings.json").path])
        #expect(paths("two/.meta.json") == [home.root.appending(path: "config/skhdrc").path])
    }

    @Test("snapshot paths from the old folder map to the new one")
    func mapsSnapshotPaths() {
        let home = URL(fileURLWithPath: "/Users/a")
        let root = URL(fileURLWithPath: "/Users/a/Library/Application Support/Macarchy")
        func location(_ path: String, startup: Bool = false) -> String {
            SnapshotStore.currentLocation(of: path, home: home, root: root, startupFiles: startup)
        }
        #expect(location("/Users/a/.config/macarchy/settings.json") == root.path + "/settings.json")
        #expect(location("/Users/a/.config/skhd/skhdrc") == "/Users/a/.config/skhd/skhdrc")
        #expect(
            location("/Users/a/.config/skhd/skhdrc", startup: true) == root.path + "/config/skhdrc")
        #expect(location("/Users/a/.config/macarchyx/a") == "/Users/a/.config/macarchyx/a")
        #expect(
            location("/Users/a/.config/ghostty/config", startup: true)
                == "/Users/a/.config/ghostty/config")
    }

    @Test("a restore says what it wrote and refuses a snapshot with no files")
    func restoreReportsFiles() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.url) }
        let store = SnapshotStore(root: home.url.appending(path: "snapshots"))
        let file = home.url.appending(path: "file")
        try "before".write(to: file, atomically: true, encoding: .utf8)
        let snapshot = try #require(try store.capture([file], reason: "test"))
        #expect(try store.restore(snapshot) == [file])
        try "{\"reason\":\"x\",\"paths\":{}}".write(
            to: snapshot.url.appending(path: ".meta.json"), atomically: true, encoding: .utf8)
        #expect(throws: SnapshotError.self) { try store.restore(snapshot) }
    }

    @Test("every file is listed, including those after a link in the same folder")
    func listsFilesAfterLinks() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: "macarchy-files-\(UUID())")
        defer { try? fm.removeItem(at: folder) }
        var expected: Set<String> = []
        for index in 0..<12 {
            let group = folder.appending(path: "g\(index)")
            try fm.createDirectory(
                at: group.appending(path: "sub"), withIntermediateDirectories: true)
            try fm.createSymbolicLink(
                at: group.appending(path: "link"), withDestinationURL: fm.temporaryDirectory)
            for name in ["a.txt", "sub/b.txt", "z.txt"] {
                try Data("x".utf8).write(to: group.appending(path: name))
            }
            expected.formUnion(["link", "a.txt", "sub/b.txt", "z.txt"].map { "g\(index)/\($0)" })
        }
        #expect(Set(LegacyLayout.files(in: folder)) == expected)
    }
}
