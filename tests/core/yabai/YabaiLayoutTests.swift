import Foundation
import Testing

@testable import Macarchy

/// An in-memory yabai that answers `-m config` reads and writes.
private actor FakeYabai {
    var config: [String: String] = [
        "layout": "bsp", "split_type": "auto", "window_placement": "second_child",
        "auto_balance": "off", "window_gap": "8", "top_padding": "8",
        "mouse_modifier": "ctrl", "mouse_follows_focus": "off", "mouse_drop_action": "stack"
    ]
    var writes: [[String]] = []
    var running = true
    var rejected: Set<String> = []

    func stop() { running = false }
    func set(_ key: String, _ value: String) { config[key] = value }
    func reject(_ key: String) { rejected.insert(key) }

    func run(_ arguments: [String]) -> CommandResult {
        guard running else {
            return CommandResult(
                command: "yabai", status: 1, stderr: "yabai-msg: failed to connect")
        }
        guard arguments.count >= 3, arguments[0] == "-m", arguments[1] == "config" else {
            return CommandResult(command: "yabai", status: 1, stderr: "unexpected")
        }
        let key = arguments[2]
        if arguments.count == 4 {
            writes.append(arguments)
            if rejected.contains(key) {
                return CommandResult(command: "yabai", status: 1, stderr: "invalid value")
            }
            config[key] = arguments[3]
            return CommandResult(command: "yabai", status: 0)
        }
        return CommandResult(command: "yabai", status: 0, stdout: config[key] ?? "")
    }
}

struct YabaiLayoutTests {
    private func temporaryStore() throws -> (URL, SettingsStore) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-layout-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, SettingsStore(url: root.appending(path: "settings.json")))
    }

    private func layout(_ yabai: FakeYabai, _ store: SettingsStore) -> YabaiLayout {
        YabaiLayout(
            integrations: Integrations { _, arguments in await yabai.run(arguments) }, store: store)
    }

    @Test("reading the running daemon never writes to it or to settings")
    func readIsReadOnly() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let yabai = FakeYabai()
        await yabai.set("window_gap", "14")

        let snapshot = try await layout(yabai, store).read()

        #expect(snapshot.source == .daemon)
        #expect(snapshot.values.windowGap == 14)
        #expect(await yabai.writes.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test("an unreachable daemon shows saved values and says why")
    func unreachableFallsBackToSaved() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.write(["YABAI_WINDOW_GAP": "20", "YABAI_LAYOUT": "stack"])
        let yabai = FakeYabai()
        await yabai.stop()

        let snapshot = try await layout(yabai, store).read()

        #expect(snapshot.source == .saved)
        #expect(snapshot.values.windowGap == 20)
        #expect(snapshot.values.layout == .stack)
        #expect(snapshot.unavailableReason?.isEmpty == false)
    }

    @Test("unreadable settings are an error, not defaults")
    func unreadableSettingsThrow() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try "broken".write(to: store.url, atomically: true, encoding: .utf8)
        let yabai = FakeYabai()
        await yabai.stop()

        await #expect(throws: (any Error).self) { try await layout(yabai, store).read() }
    }

    @Test("an edit applies to yabai, then saves in the settings format")
    func applyThenSave() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let yabai = FakeYabai()
        var changes = LayoutChanges()
        changes.windowGap = 12
        changes.mouseFollowsFocus = true
        changes.autoBalance = true

        let result = await layout(yabai, store).apply(changes, linkPadding: true)

        #expect(result.ok)
        #expect(await yabai.config["window_gap"] == "12")
        #expect(await yabai.config["mouse_follows_focus"] == "on")
        #expect(await yabai.config["auto_balance"] == "on")
        let saved = try store.read().flatValues
        #expect(saved["YABAI_WINDOW_GAP"] == "12")
        #expect(saved["YABAI_MOUSE_FOLLOWS_FOCUS"] == "on")
        #expect(saved["YABAI_AUTO_BALANCE"] == "on")
    }

    @Test("linked padding sets every edge; unlinked sets only the top")
    func paddingEdges() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let yabai = FakeYabai()
        var changes = LayoutChanges()
        changes.padding = 16

        _ = await layout(yabai, store).apply(changes, linkPadding: false)
        #expect(await yabai.writes.map { $0[2] } == ["top_padding"])

        _ = await layout(yabai, store).apply(changes, linkPadding: true)
        #expect(
            await yabai.writes.dropFirst().map { $0[2] } == [
                "top_padding", "bottom_padding", "left_padding", "right_padding"
            ])
        #expect(try store.read().flatValues["YABAI_LEFT_PADDING"] == "16")
    }

    @Test("a rejected write is reported and nothing is saved")
    func rejectedWriteIsNotSaved() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.write(["YABAI_WINDOW_GAP": "8"])
        let yabai = FakeYabai()
        await yabai.reject("mouse_modifier")
        var changes = LayoutChanges()
        changes.windowGap = 30
        changes.mouseModifier = .alt

        let result = await layout(yabai, store).apply(changes, linkPadding: true)

        #expect(!result.ok)
        #expect(result.stderr.contains("Applied window_gap but not saved"))
        #expect(try store.read().flatValues["YABAI_WINDOW_GAP"] == "8")
    }

    @Test("an unreachable daemon refuses the edit and saves nothing")
    func unreachableRefusesEdit() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let yabai = FakeYabai()
        await yabai.stop()
        var changes = LayoutChanges()
        changes.layout = .float

        let result = await layout(yabai, store).apply(changes, linkPadding: true)

        #expect(!result.ok)
        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }

    @Test("out-of-range values never reach yabai")
    func rangesAreChecked() async throws {
        let (root, store) = try temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let yabai = FakeYabai()
        var changes = LayoutChanges()
        changes.windowGap = 400

        let result = await layout(yabai, store).apply(changes, linkPadding: true)

        #expect(!result.ok)
        #expect(await yabai.writes.isEmpty)
    }

    @Test("the page's values decode from the bridge's JSON")
    func changesDecode() throws {
        let json = #"{"windowPlacement":"first_child","padding":12,"mouseDropAction":"swap"}"#
        let changes = try JSONDecoder().decode(LayoutChanges.self, from: Data(json.utf8))
        #expect(changes.windowPlacement == .firstChild)
        #expect(changes.padding == 12)
        #expect(changes.mouseDropAction == .swap)
        #expect(changes.layout == nil)
        let invalid = #"{"layout":"spiral"}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(LayoutChanges.self, from: Data(invalid.utf8))
        }
    }
}

struct TerminalPaletteTests {
    @Test("ghostty palettes and theme colours normalise to #rrggbb")
    func parsesPalette() {
        let palette = TerminalPalette.parse(
            """
            # comment
            background = #141010
            foreground = #DACBE6
            palette = 4=#e68e0d
            palette = 1 = #f56728
            """)
        #expect(palette.background == "#141010")
        #expect(palette.foreground == "#dacbe6")
        #expect(palette.ansi(4) == "#e68e0d")
        #expect(palette.ansi(1) == "#f56728")
        #expect(palette.ansi(2) == "#dacbe6")
        #expect(TerminalPalette.rgb("0xffffff00") == "#ffff00")
        #expect(TerminalPalette.rgb("nonsense") == nil)
    }
}
