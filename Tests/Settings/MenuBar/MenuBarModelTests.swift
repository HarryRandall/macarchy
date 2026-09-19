import Foundation
import Testing
@testable import Desktop
@testable import Settings

@MainActor
struct MenuBarModelTests {
    @Test("draft additions do not write until Apply; saved components survive loading")
    func applyAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let store = BarConfigurationStore(directory: root)
        let model = MenuBarModel(
            backend: backend, log: CommandLog(), configurationStore: store,
            settingsStore: SettingsEnv(
                url: root.appending(path: "settings.env"),
                snapshots: SnapshotStore(root: root.appending(path: "snapshots"))))
        await model.hydrate()
        model.add(kind: "text")
        let id = try #require(model.selected)
        model.update(id) { $0.text = "Custom label" }
        #expect(await backend.recordedWrites().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.documentURL.path))
        #expect(try store.loadDraft()?.components.first { $0.id == id }?.text == "Custom label")
        await model.apply()
        #expect(model.error == nil)
        #expect(!model.hasChanges)
        let saved = try #require(try store.load())
        #expect(saved.components.first { $0.id == id }?.text == "Custom label")
        #expect(saved.padding == 2 && saved.spacing == 4)
        let replay = try String(contentsOf: store.scriptURL, encoding: .utf8)
        #expect(replay.contains("label=Custom label"))
        await model.hydrate()
        #expect(model.draft.components.first { $0.id == id }?.kind == "text")
    }

    @Test("failed Apply keeps the draft and does not save it as successfully applied")
    func failureAndRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let store = BarConfigurationStore(directory: root)
        let model = MenuBarModel(
            backend: backend, log: CommandLog(), configurationStore: store,
            settingsStore: SettingsEnv(
                url: root.appending(path: "settings.env"),
                snapshots: SnapshotStore(root: root.appending(path: "snapshots"))))
        await model.hydrate()
        model.add(kind: "spacer")
        await backend.setFailure(true)
        await model.apply()
        #expect(model.hasChanges)
        #expect(model.error != nil)
        #expect(!FileManager.default.fileExists(atPath: store.documentURL.path))
        await backend.setFailure(false)
        await model.apply()
        #expect(model.error == nil)
        #expect(!model.hasChanges)
    }
    @Test("bulk selection edits only selected groups and undo restores the whole edit")
    func bulkSelection() {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = MenuBarModel(
            backend: MenuBarTestBackend(), log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        model.draft.components = ["cpu", "ram", "clock"].map {
            BarComponent(id: $0, title: $0, side: "right", members: [$0])
        }
        model.select("cpu")
        model.select("ram", extending: true)
        model.updateSelection {
            $0.paddingOverride = 0; $0.spacingOverride = 3
        }
        #expect(model.draft.components[0].paddingOverride == 0)
        #expect(model.draft.components[1].spacingOverride == 3)
        #expect(model.draft.components[2].paddingOverride == nil)
        model.moveToSide("cpu", side: "left")
        #expect(model.draft.components.filter { $0.side == "left" }.map(\.id) == ["cpu", "ram"])
        model.undoLast()
        #expect(model.draft.components.allSatisfy { $0.side == "right" })
        model.undoLast()
        #expect(model.draft.components.allSatisfy { $0.paddingOverride == nil })
        model.selectAll()
        #expect(model.selection.count == 3)
    }

}
