import Foundation
import Testing

@testable import Macarchy

struct WindowRuleSettingsTests {
    private func temporary() throws -> (URL, SettingsStore) {
        let root = FileManager.default.temporaryDirectory.appending(path: "rules-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, SettingsStore(url: root.appending(path: "settings.json")))
    }

    @Test("reads saved pending rules and live external rules without writing")
    func readOnly() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let rule = CustomWindowRule(app: "Finder")
        try store.update {
            $0.floatingApps = ["Messages"]; $0.windowRules = [rule]
        }
        let before = try Data(contentsOf: store.url)
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        let snapshot = try await settings.read()
        #expect(snapshot.floatingApps == ["Messages"])
        #expect(snapshot.customRules == [rule])
        #expect(snapshot.externalRules.map(\.app) == ["System Settings"])
        #expect(snapshot.externalRules.first?.title == "^General$")
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await fake.calls == [["-m", "rule", "--list"]])
        #expect(snapshot.unavailableReason == nil)
    }

    @Test("a stopped yabai still shows saved rules, with a reason and no external rules")
    func unavailableDaemon() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
        try store.update {
            $0.floatingApps = ["Messages"]; $0.windowRules = [rule]
        }
        let before = try Data(contentsOf: store.url)
        let fake = RulesSettingsFake(listFailure: "could not connect to yabai")
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        let snapshot = try await settings.read()
        #expect(snapshot.floatingApps == ["Messages"])
        #expect(snapshot.customRules == [rule])
        #expect(snapshot.externalRules.isEmpty)
        #expect(snapshot.unavailableReason?.contains("saved rules") == true)
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await fake.calls == [["-m", "rule", "--list"]])
    }

    @Test("a stopped yabai with no saved settings shows empty saved rules, not a failure")
    func unavailableDaemonWithoutSettings() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = RulesSettingsFake(listFailure: "")
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        let snapshot = try await settings.read()
        #expect(snapshot.floatingApps.isEmpty)
        #expect(snapshot.customRules.isEmpty)
        #expect(snapshot.unavailableReason?.isEmpty == false)
        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }

    @Test("unreadable settings and unreadable daemon output never become empty state")
    func unreadable() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        try "broken".write(to: store.url, atomically: true, encoding: .utf8)
        await #expect(throws: (any Error).self) { try await settings.read() }
        #expect(await fake.calls.isEmpty)
        try FileManager.default.removeItem(at: store.url)
        await fake.setList("broken")
        await #expect(throws: ConfigurationError.self) { try await settings.read() }
    }

    @Test("named edits preserve unrelated preferences and reconcile all rules")
    func edits() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update { $0.currentTheme = "midnight" }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        try await settings.setFloating(app: "Messages", floating: true)
        try await settings.setFloating(app: "Calculator", floating: true)
        try await settings.setFloating(app: "Messages", floating: true)
        #expect(try store.read().floatingApps == ["Calculator", "Messages"])
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
        try await settings.save(rule)
        try await settings.save(CustomWindowRule(id: rule.id, app: "Finder", title: "^Move$"))
        #expect(try store.read().windowRules?.map(\.title) == ["^Move$"])
        try await settings.removeCustom(id: rule.id)
        try await settings.setFloating(app: "Messages", floating: false)
        #expect(try store.read().floatingApps == ["Calculator"])
        #expect(try store.read().windowRules?.isEmpty == true)
        #expect(try store.read().currentTheme == "midnight")
        #expect(await fake.calls.contains(rule.arguments))
    }

    @Test("an unrelated edit adopts apps that float only through a live rule")
    func adoptsLiveFloating() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update { $0.floatingApps = ["Calculator"] }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        #expect(try await settings.read().floatingApps == ["Calculator", "Messages"])
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
        try await settings.save(rule)
        #expect(try store.read().floatingApps == ["Calculator", "Messages"])
        #expect(try store.read().windowRules == [rule])
        let calls = await fake.calls
        #expect(calls.contains { $0.contains("label=float_persist_Messages") })
        #expect(calls.contains { $0.contains("label=float_persist_Calculator") })
        #expect(try await settings.read().floatingApps == ["Calculator", "Messages"])
    }

    @Test("removing a floating app that exists only as a live rule removes it everywhere")
    func removesLiveFloating() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update { $0.currentTheme = "midnight" }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        try await settings.setFloating(app: "Messages", floating: false)
        #expect(try store.read().floatingApps.isEmpty)
        let calls = await fake.calls
        #expect(calls.contains(["-m", "rule", "--remove", "0"]))
        #expect(!calls.contains { $0.contains("label=float_persist_Messages") })
    }

    @Test("saving an edited rule that was removed elsewhere fails without recreating it")
    func removedElsewhere() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let kept = CustomWindowRule(app: "Calculator")
        try store.update { $0.windowRules = [kept] }
        let before = try Data(contentsOf: store.url)
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        do {
            try await settings.save(CustomWindowRule(app: "Finder"), existing: true)
            Issue.record("Expected failure")
        } catch let error as ConfigurationError {
            #expect(error.localizedDescription.contains("removed elsewhere"))
        }
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await fake.calls.isEmpty)
        try await settings.save(
            CustomWindowRule(id: kept.id, app: "Calculator", title: "^Main$"), existing: true)
        #expect(try store.read().windowRules?.map(\.title) == ["^Main$"])
    }

    @Test("validation rejects edits before calling the desktop")
    func validation() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        await #expect(throws: ConfigurationError.self) {
            try await settings.save(CustomWindowRule(app: "Finder", title: "["))
        }
        await #expect(throws: ConfigurationError.self) {
            try await settings.setFloating(app: "\n", floating: true)
        }
        await #expect(throws: ConfigurationError.self) {
            try await settings.removeCustom(id: "bad")
        }
        #expect(await fake.calls.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }

    @Test("failed floating apply keeps saved bytes and restores previous rules")
    func failedFloating() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = CustomWindowRule(app: "Messages")
        try store.update { $0.windowRules = [original] }
        let before = try Data(contentsOf: store.url)
        let fake = RulesSettingsFake(rejected: "app=^Finder$")
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        await #expect(throws: ConfigurationError.self) {
            try await settings.setFloating(app: "Finder", floating: true)
        }
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await fake.calls.contains(original.arguments))
    }

    @Test("persistence failure restores the applied rules and leaves preferences unchanged")
    func persistenceFailure() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = CustomWindowRule(app: "Messages")
        try store.update { $0.windowRules = [original] }
        let before = try Data(contentsOf: store.url)
        try Data().write(to: root.appending(path: "snapshots"))
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        let replacement = CustomWindowRule(app: "Finder")
        await #expect(throws: (any Error).self) { try await settings.save(replacement) }
        #expect(try Data(contentsOf: store.url) == before)
        let calls = await fake.calls
        #expect(calls.contains(replacement.arguments))
        #expect(calls.last == original.arguments)
    }

    @Test("concurrent floating edits keep both applications")
    func concurrentEdits() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = RulesSettingsFake()
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        async let first: Void = settings.setFloating(app: "Messages", floating: true)
        async let second: Void = settings.setFloating(app: "Calculator", floating: true)
        _ = try await (first, second)
        #expect(try store.read().floatingApps == ["Calculator", "Messages"])
    }

    @Test("rollback failures explicitly report that the desktop needs recovery")
    func rollbackFailure() async throws {
        let (root, store) = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.update { $0.floatingApps = ["Messages"] }
        let before = try Data(contentsOf: store.url)
        let fake = RulesSettingsFake(rejected: "manage=off")
        let settings = WindowRuleSettings(
            store: store, integrations: Integrations(execute: fake.run))
        do {
            try await settings.save(CustomWindowRule(app: "Finder"))
            Issue.record("Expected failure")
        } catch {
            #expect(error.localizedDescription.contains("Restoring the previous rules also failed"))
        }
        #expect(try Data(contentsOf: store.url) == before)
    }
}

private actor RulesSettingsFake {
    var calls: [[String]] = []
    var list = """
        [{"index":0,"label":"float_persist_Messages","app":"^Messages$"},
         {"index":1,"label":"macarchy_custom_example","app":"^Finder$"},
         {"index":2,"label":"external","app":"^System Settings$","title":"^General$"}]
        """
    let rejected: String?
    let listFailure: String?
    init(rejected: String? = nil, listFailure: String? = nil) {
        self.rejected = rejected
        self.listFailure = listFailure
    }
    func setList(_ value: String) { list = value }
    func run(_ path: String, _ arguments: [String]) async -> CommandResult {
        calls.append(arguments)
        if arguments.contains("--list") {
            if let listFailure {
                return CommandResult(command: "fake rules", status: 1, stderr: listFailure)
            }
            return CommandResult(command: "fake rules", status: 0, stdout: list)
        }
        if let rejected, arguments.contains(rejected) {
            return CommandResult(command: "fake rules", status: 1, stderr: "Rule rejected")
        }
        return CommandResult(command: "fake rules", status: 0)
    }
}
