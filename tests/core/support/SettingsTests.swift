import Foundation
import Testing
@testable import Macarchy

struct SettingsTests {
    func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-settings-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    @Test func readsDoNotWrite() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        _ = try store.read()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
    @Test func malformedJSONIsNotReplaced() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "settings.json")
        try "broken".write(to: url, atomically: true, encoding: .utf8)
        let store = SettingsStore(url: url)
        #expect(throws: (any Error).self) { try store.set("BORDER_WIDTH", "7") }
        #expect(try String(contentsOf: url, encoding: .utf8) == "broken")
    }
    @Test func unchangedWritesDoNotSnapshot() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.set("BORDER_WIDTH", "7")
        try store.set("BORDER_WIDTH", "7")
        #expect(SnapshotStore(root: root.appending(path: "snapshots")).list().isEmpty)
        #expect(try store.read().borders["border_width"] == .number(7))
    }
    @Test func rejectedApplyIsNotSaved() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.set("YABAI_WINDOW_GAP", "8")
        let result = await SettingsApply().apply(values: ["YABAI_WINDOW_GAP": "12"], store: store) {
            CommandResult(command: "fake", status: 1, stderr: "Rejected")
        }
        #expect(!result.ok)
        #expect(try store.load()["YABAI_WINDOW_GAP"] == "8")
    }
    @Test func overlappingEditsFinishInSubmissionOrder() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        let queue = SettingsApply()
        let (started, start) = AsyncStream<Void>.makeStream()
        let (released, release) = AsyncStream<Void>.makeStream()
        // The first edit's command signals once it is running, then holds
        // until the second edit has joined the queue behind it.
        let first = await queue.enqueue(values: ["YABAI_WINDOW_GAP": "9"], store: store) {
            start.finish()
            for await _ in released {}
            return CommandResult(command: "first", status: 0)
        }
        for await _ in started {}
        let second = await queue.enqueue(values: ["YABAI_WINDOW_GAP": "10"], store: store) {
            CommandResult(command: "second", status: 0)
        }
        release.finish()
        _ = await first.value
        #expect(await second.value.ok)
        #expect(try store.load()["YABAI_WINDOW_GAP"] == "10")
    }
    @Test func concurrentWritersPreserveUnrelatedKeys() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<12 {
                group.addTask { try store.set("YABAI_TEST_\(index)", String(index)) }
            }
            try await group.waitForAll()
        }
        #expect(try store.read().layout.count == 12)
    }

    /// Double reads hex, so colours used to be saved as decimal numbers.
    @Test func hexColoursStayHex() throws {
        var document = SettingsDocument()
        let adopted = StartupConfiguration.adoptYabai(
            "yabai -m config insert_feedback_color 0xffd75f5f\n")
        document.mergeFlat(adopted.values)
        document.mergeFlat(["YABAI_WINDOW_GAP": "12", "YABAI_TOP_PADDING": "1e3"])
        #expect(document.layout["insert_feedback_color"] == .text("0xffd75f5f"))
        #expect(document.flatValues["YABAI_INSERT_FEEDBACK_COLOR"] == "0xffd75f5f")
        #expect(document.layout["window_gap"] == .number(12))
        #expect(document.layout["top_padding"] == .text("1e3"))
        // A colour an earlier version saved as decimal is handed back in hex.
        document.layout["insert_feedback_color"] = .number(4_292_304_735)
        #expect(document.flatValues["YABAI_INSERT_FEEDBACK_COLOR"] == "0xffd75f5f")
    }

    /// Keys may be left out and take their defaults; the schema may not.
    @Test func decodingNamesTheFileAndKey() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "settings.json")
        let store = SettingsStore(url: url)
        func message(_ json: String) throws -> String {
            try json.write(to: url, atomically: true, encoding: .utf8)
            do { _ = try store.read() } catch { return error.localizedDescription }
            return "read succeeded"
        }
        try #"{"schema":1,"currentTheme":"midnight"}"#.write(
            to: url, atomically: true, encoding: .utf8)
        #expect(try store.read().currentTheme == "midnight")
        #expect(try store.read().layout.isEmpty)
        #expect(
            try message(#"{"currentTheme":"midnight"}"#).hasSuffix(
                "settings.json: schema is missing."))
        #expect(
            try message(#"{"schema":1,"floatingApps":"Finder"}"#).hasSuffix(
                "settings.json: floatingApps should be a list."))
        #expect(
            try message(#"{"schema":1,"itemVisibility":{"clock":"yes"}}"#).hasSuffix(
                "settings.json: itemVisibility.clock should be true or false."))
        let broken = try message(#"{"schema":1"#)
        #expect(broken.contains("settings.json is not valid JSON"), "\(broken)")
        #expect(try message(#"{"schema":2}"#).contains("newer Macarchy"))
        #expect(try message(#"{"schema":1,"currentTheme":"../x"}"#).contains("settings.json: "))
    }

    /// Keys a newer version added survive a write by this one.
    @Test func unknownKeysSurviveWrites() throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "settings.json")
        try #"{"schema":1,"futureFeature":{"x":[1,true,null,"a"]}}"#.write(
            to: url, atomically: true, encoding: .utf8)
        let store = SettingsStore(url: url)
        try store.set("YABAI_WINDOW_GAP", "9")
        let document = try store.read()
        #expect(
            document.unknownKeys["futureFeature"]
                == .object(["x": .array([.number(1), .bool(true), .null, .string("a")])]))
        #expect(document.layout["window_gap"] == .number(9))
    }
}
