import Foundation
import Testing

@testable import Macarchy

@Suite("Widget catalogue")
struct WidgetCatalogueTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "widgets-\(UUID())")
    private var builtIn: URL { root.appending(path: "built-in") }
    private var user: URL { root.appending(path: "user") }

    private func make(_ id: String, in folder: URL, name: String? = nil, json: String? = nil) throws
    {
        let directory = folder.appending(path: name ?? id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let text =
            json
            ?? #"{"schema": 1, "id": "\#(id)", "name": "\#(id.capitalized)", "version": "1.0.0"}"#
        try Data(text.utf8).write(to: directory.appending(path: "widget.json"))
    }

    private func catalogue() -> WidgetCatalogue { WidgetCatalogue(builtIn: builtIn, user: user) }

    @Test("reads built-in widgets and people's own, built-ins first")
    func reads() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("clock", in: builtIn)
        try make("uptime", in: user)
        let snapshot = catalogue().read()
        #expect(snapshot.entries.map(\.id) == ["clock", "uptime"])
        #expect(snapshot.entries.map(\.origin) == [.builtIn, .user])
        #expect(snapshot.problems.isEmpty)
        #expect(snapshot.entry("uptime")?.directory.lastPathComponent == "uptime")
    }

    @Test("a missing folder means no widgets, not an error")
    func missing() {
        let snapshot = catalogue().read()
        #expect(snapshot.entries.isEmpty && snapshot.problems.isEmpty)
    }

    @Test("a person's widget cannot reuse a built-in id")
    func shadowing() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("clock", in: builtIn)
        try make("clock", in: user)
        let snapshot = catalogue().read()
        #expect(snapshot.entries.map(\.origin) == [.builtIn])
        #expect(
            snapshot.problems["clock"]?.map(\.message)
                == [
                    "clock is the id of a built-in widget; give this one another id and folder name"
                ])
    }

    @Test("broken folders are listed with their problems, and hidden folders are skipped")
    func broken() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("good", in: user)
        try make("bad", in: user, json: "{")
        try make("hidden", in: user, name: ".hidden")
        let snapshot = catalogue().read()
        #expect(snapshot.entries.map(\.id) == ["good"])
        #expect(Array(snapshot.problems.keys) == ["bad"])
    }

    @Test("a folder that links outside the widgets folder is refused")
    func symlink() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("outside", in: root)
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: user.appending(path: "outside"), withDestinationURL: root.appending(path: "outside")
        )
        let snapshot = catalogue().read()
        #expect(snapshot.entries.isEmpty)
        #expect(
            snapshot.problems["outside"]?.map(\.message) == ["links outside its widgets folder"])
    }

    @Test("new ids avoid every widget and every folder, broken ones included")
    func unusedIDs() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("clock", in: builtIn)
        try make("uptime", in: user, json: "not json")
        let taken = catalogue().takenIDs()
        #expect(taken == ["clock", "uptime"])
        #expect(WidgetCatalogue.unusedID(from: "uptime", taken: taken) == "uptime-2")
        #expect(
            WidgetCatalogue.unusedID(from: "uptime", taken: taken.union(["uptime-2"])) == "uptime-3"
        )
        #expect(WidgetCatalogue.unusedID(from: "weather", taken: taken) == "weather")
    }

    @Test("the report lists widgets and checks one by id or folder")
    func report() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try make("clock", in: builtIn)
        try make("bad", in: user, json: "{\n  \"schema\": 1,\n}")
        let lines = WidgetReport.list(catalogue())
        #expect(lines.first == "clock  Clock  built-in")
        #expect(lines.contains("  bad/widget.json, line 3: Remove the comma before }"))
        #expect(
            WidgetReport.check("clock", catalogue: catalogue()) == (
                ["clock: Clock 1.0.0 is ready."], true
            ))
        let byPath = WidgetReport.check("user/bad", catalogue: catalogue(), workingDirectory: root)
        #expect(!byPath.ok)
        #expect(WidgetReport.check("nothing", catalogue: catalogue()).ok == false)
    }
}
