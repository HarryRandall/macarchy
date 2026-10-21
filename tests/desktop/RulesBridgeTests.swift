import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
struct RulesBridgeTests {
    private func temporary() throws -> (URL, SettingsStore) {
        let root = FileManager.default.temporaryDirectory.appending(path: "rules-bridge-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, SettingsStore(url: root.appending(path: "settings.json")))
    }

    @Test("typed rule requests reach the isolated core and preserve unrelated preferences")
    func namedRequests() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update { $0.currentTheme = "midnight" }
        let model = AppModel(
            backend: Integrations { _, arguments in
                CommandResult(
                    command: "fake", status: 0,
                    stdout: arguments.contains("--list") ? "[]" : "")
            }, settingsStore: store)
        let router = BridgeRouter()
        router.registerRules(model: model, chooseApplication: { "Calculator" })
        let before = try Data(contentsOf: store.url)
        let state = await router.handle(["method": "rules.getState"])
        #expect(state.contains("\"externalRules\":[]"))
        #expect(try Data(contentsOf: store.url) == before)
        #expect(
            await router.handle(["method": "rules.addApplication"]) == #"{"ok":true,"value":null}"#)
        #expect(try store.read().floatingApps == ["Calculator"])
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
        let save = await router.handle([
            "method": "rules.saveCustom",
            "params": ["rule": ["id": rule.id, "app": rule.app, "title": rule.title]]
        ])
        #expect(save == #"{"ok":true,"value":null}"#)
        #expect(try store.read().windowRules == [rule])
        _ = await router.handle(["method": "rules.removeCustom", "params": ["id": rule.id]])
        _ = await router.handle(["method": "rules.removeFloating", "params": ["app": "Calculator"]])
        #expect(try store.read().windowRules?.isEmpty == true)
        #expect(try store.read().floatingApps.isEmpty)
        #expect(try store.read().currentTheme == "midnight")
    }

    @Test("cancelling the application picker never writes or applies")
    func cancelledPicker() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(
            backend: Integrations { _, _ in
                Issue.record("Cancelled picker must not reach the desktop")
                return CommandResult(command: "fake", status: 1)
            }, settingsStore: store)
        let router = BridgeRouter()
        router.registerRules(model: model, chooseApplication: { nil })
        #expect(
            await router.handle(["method": "rules.addApplication"]) == #"{"ok":true,"value":null}"#)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test("validation failures are visible operation errors and do not persist")
    func invalidRule() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let router = BridgeRouter()
        let model = AppModel(
            backend: Integrations { _, _ in
                Issue.record("Invalid rules must not reach the desktop")
                return CommandResult(command: "fake", status: 1)
            }, settingsStore: store)
        router.registerRules(model: model, chooseApplication: { nil })
        let reply = await router.handle([
            "method": "rules.saveCustom",
            "params": ["rule": ["id": UUID().uuidString, "app": "Finder", "title": "["]]
        ])
        #expect(reply.contains("operation_failed"))
        #expect(reply.contains("Invalid window title pattern"))
        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }
}
