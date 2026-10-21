import Foundation
import Testing

@testable import Macarchy

struct ThemeCollectionTests {
    private struct Fixture {
        var root: URL
        var collection: ThemeCollection
        var store: SettingsStore
    }

    private func fixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "theme-collection-\(UUID())")
        let themes = root.appending(path: "themes")
        let installed = themes.appending(path: "sample")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        var theme = Theme(name: "sample")
        theme.colors.borderActive = "0xff123456"
        theme.apps.nvimColorscheme = "missing-scheme"
        try theme.write(to: installed)
        try Data("background = #abcdef\npalette = 4=#123456".utf8).write(
            to: installed.appending(path: "ghostty.conf"))
        let resources = root.appending(path: "resources")
        try FileManager.default.createDirectory(
            at: resources.appending(path: "themes"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: installed, to: resources.appending(path: "themes/sample"))
        return Fixture(
            root: root, collection: ThemeCollection(root: themes, resources: resources),
            store: SettingsStore(url: root.appending(path: "settings.json")))
    }

    @Test("listing reads real manifests, palettes and selections without writing")
    func readOnly() throws {
        let fixture = try fixture()
        let root = fixture.root
        let collection = fixture.collection
        let store = fixture.store
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update {
            $0.currentTheme = "sample"; $0.wallpapers["sample"] = "backgrounds/a.png"
        }
        let before = try Data(contentsOf: store.url)
        let snapshot = try collection.read(store: store)
        #expect(snapshot.current == "sample")
        #expect(snapshot.themes.map(\.name) == ["sample"])
        #expect(snapshot.themes.first?.terminal?.background == "#abcdef")
        #expect(snapshot.wallpapers["sample"] == "backgrounds/a.png")
        #expect(try Data(contentsOf: store.url) == before)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "snapshots").path))
    }

    @Test("individual edits preserve unrelated manifest fields and reset uses the shipped baseline")
    func editsAndReset() throws {
        let fixture = try fixture()
        let root = fixture.root
        let collection = fixture.collection
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = try collection.directory(named: "sample")
        let original = try Theme.read(from: directory)
        try collection.setDark(theme: "sample", dark: false)
        for colour in [
            ThemeCollection.Colour.borderActive, .borderInactive, .sketchybarBar, .sketchybarText,
            .firefoxAccent
        ] {
            try collection.setColour(theme: "sample", colour: colour, value: "#abcdef")
        }
        try collection.setColourscheme(theme: "sample", value: nil)
        let edited = try Theme.read(from: directory)
        #expect(!edited.dark)
        #expect(edited.colors.firefoxAccent == "#abcdef")
        #expect(edited.apps.nvimColorscheme == nil)
        #expect(edited.name == original.name)
        #expect(edited != collection.bundledDefault(named: "sample"))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "snapshots").path))
        try collection.reset(theme: "sample")
        #expect(try Theme.read(from: directory) == original)
    }

    @Test(
        "invalid values, arbitrary theme paths and a missing default leave the manifest unchanged")
    func rejectsInvalidEdits() throws {
        let fixture = try fixture()
        let root = fixture.root
        let collection = fixture.collection
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try collection.directory(named: "sample").appending(path: "theme.json")
        let before = try Data(contentsOf: file)
        #expect(throws: (any Error).self) {
            try collection.setColour(theme: "sample", colour: .borderActive, value: "red")
        }
        #expect(throws: (any Error).self) {
            try collection.setColourscheme(theme: "sample", value: "bad;command")
        }
        #expect(throws: (any Error).self) {
            try collection.setDark(theme: "../sample", dark: false)
        }
        #expect(throws: (any Error).self) {
            try ThemeCollection(root: collection.library.root, resources: nil).reset(
                theme: "sample")
        }
        #expect(try Data(contentsOf: file) == before)
    }

    @Test("unreadable settings fail and invalid installed manifests are reported")
    func invalidState() throws {
        let fixture = try fixture()
        let root = fixture.root
        let collection = fixture.collection
        let store = fixture.store
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("broken".utf8).write(to: store.url)
        #expect(throws: (any Error).self) { try collection.read(store: store) }
        try FileManager.default.removeItem(at: store.url)
        try Theme(name: "different").write(to: collection.library.root.appending(path: "sample"))
        let snapshot = try collection.read(store: store)
        #expect(snapshot.themes.isEmpty)
        #expect(snapshot.warnings.first?.contains("disagree") == true)
    }

    @Test("background discovery includes root images but refuses links outside the theme")
    func backgrounds() throws {
        let fixture = try fixture()
        let root = fixture.root
        let collection = fixture.collection
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = try collection.directory(named: "sample")
        try Data().write(to: directory.appending(path: "one.png"))
        try Data().write(to: root.appending(path: "private.png"))
        try FileManager.default.createSymbolicLink(
            at: directory.appending(path: "escape.png"),
            withDestinationURL: root.appending(path: "private.png"))
        #expect(ThemeCollection.backgrounds(in: directory).map(\.lastPathComponent) == ["one.png"])
    }
}
