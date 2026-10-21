import Foundation
import Testing
@testable import Macarchy

@Suite("Optional window rules")
struct WindowRulesTests {
    private func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-rules-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("older settings decode without enabling optional presets")
    func oldSettings() throws {
        let data = try JSONEncoder().encode(SettingsDocument())
        let decoded = try JSONDecoder().decode(SettingsDocument.self, from: data)
        #expect(decoded.windowRules == nil)
        #expect(decoded.floatingApps.isEmpty)
    }

    @Test("custom title rules survive settings encoding")
    func roundTrip() throws {
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$|^Move$")
        var settings = SettingsDocument()
        settings.windowRules = [rule]
        try settings.validate()
        let decoded = try JSONDecoder().decode(
            SettingsDocument.self, from: JSONEncoder().encode(settings))
        #expect(decoded.windowRules == [rule])
        #expect(rule.arguments.contains("title=^Copy$|^Move$"))
        #expect(rule.arguments.contains("app=^Finder$"))
    }

    @Test("app names are literal and blank titles apply to all windows")
    func literalApp() throws {
        let rule = CustomWindowRule(app: "App (Preview)")
        try rule.validate()
        #expect(rule.arguments.contains("app=^App \\(Preview\\)$"))
        #expect(!rule.arguments.contains { $0.hasPrefix("title=") })
    }

    @Test("invalid patterns and duplicate identifiers are rejected before applying")
    func validation() throws {
        #expect(throws: ConfigurationError.self) {
            try CustomWindowRule(app: "Finder", title: "[").validate()
        }
        #expect(throws: ConfigurationError.self) { try CustomWindowRule(app: " ").validate() }
        let rule = CustomWindowRule(app: "Finder")
        var settings = SettingsDocument()
        settings.windowRules = [rule, rule]
        #expect(throws: ConfigurationError.self) { try settings.validate() }
    }

    @Test("reconciliation replaces only owned rules and preserves Macarchy placement")
    func reconcile() async throws {
        let spy = RuleSpy(
            list: """
                [{"index":2,"label":"float_persist_Old"},{"index":5,"label":"macarchy_custom_old"},
                 {"index":6,"label":"macarchy_workspace"},{"index":7,"label":"foreign"}]
                """)
        let custom = CustomWindowRule(app: "Finder", title: "^Copy$")
        try await WindowRules.apply(
            ["Messages"], customRules: [custom], integrations: Integrations(execute: spy.run))
        let calls = await spy.calls
        #expect(
            calls.filter { $0.contains("--remove") } == [
                ["-m", "rule", "--remove", "5"], ["-m", "rule", "--remove", "2"]
            ])
        #expect(calls.contains(custom.arguments))
        #expect(calls.contains { $0.contains("label=float_persist_Messages") })
    }

    @Test("Save persists custom rules and preserves existing preferences")
    func save() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update {
            $0.floatingApps = ["Messages"]; $0.currentTheme = "midnight"
        }
        let spy = RuleSpy(list: "[]")
        let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
        try await WindowRules.commitCustom(
            [rule], store: store, integrations: Integrations(execute: spy.run))
        #expect(try store.read().windowRules == [rule])
        #expect(try store.read().floatingApps == ["Messages"])
        #expect(try store.read().currentTheme == "midnight")
        try await WindowRules.commitCustom(
            [], store: store, integrations: Integrations(execute: spy.run))
        #expect(try store.read().windowRules?.isEmpty == true)
    }

    @Test("failed custom rule apply keeps saved preferences and replays previous rules")
    func failedSave() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        let original = CustomWindowRule(app: "Messages")
        try store.update { $0.windowRules = [original] }
        let spy = RuleSpy(list: "[]", rejectApp: "app=^Finder$")
        await #expect(throws: ConfigurationError.self) {
            try await WindowRules.commitCustom(
                [CustomWindowRule(app: "Finder")], store: store,
                integrations: Integrations(execute: spy.run))
        }
        #expect(try store.read().windowRules == [original])
        #expect(await spy.calls.contains(original.arguments))
    }

}

private actor RuleSpy {
    var calls: [[String]] = []
    let list: String
    let rejectApp: String?
    init(list: String, rejectApp: String? = nil) { self.list = list; self.rejectApp = rejectApp }
    func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        calls.append(arguments)
        if arguments.contains("--list") {
            return CommandResult(command: "mock", status: 0, stdout: list)
        }
        if let rejectApp, arguments.contains(rejectApp) {
            return CommandResult(command: "mock", status: 1, stderr: "Rejected")
        }
        return CommandResult(command: "mock", status: 0)
    }
}
