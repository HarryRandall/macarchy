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
        // ICU-only syntax that yabai's POSIX extended regex rejects.
        for pattern in ["(?i)copy", "Copy(?= of)"] {
            #expect(throws: ConfigurationError.self) {
                try CustomWindowRule(app: "Finder", title: pattern).validate()
            }
        }
        try CustomWindowRule(app: "Finder", title: "^Copy [[:digit:]]+$").validate()
        let rule = CustomWindowRule(app: "Finder")
        var settings = SettingsDocument()
        settings.windowRules = [rule, rule]
        #expect(throws: ConfigurationError.self) { try settings.validate() }
    }

    /// Hand-made `float_persist_` rules sit at 3, 4, 8 and 9: one with a title,
    /// one matching several apps, one with no app and one whose app is not the
    /// label's. None of them is what `apply` writes, so none is removed.
    @Test("reconciliation replaces only owned rules and preserves Macarchy placement")
    func reconcile() async throws {
        let spy = RuleSpy(
            list: """
                [{"index":2,"label":"float_persist_Old","app":"^Old$","title":""},
                 {"index":3,"label":"float_persist_x","app":"^Safari$","title":"^Settings"},
                 {"index":4,"label":"float_persist_y","app":"^(Notes|Calculator)$"},
                 {"index":5,"label":"macarchy_custom_old"},
                 {"index":6,"label":"macarchy_workspace"},{"index":7,"label":"foreign"},
                 {"index":8,"label":"float_persist_z"},
                 {"index":9,"label":"float_persist_Mail","app":"^Mail"}]
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

    @Test("only rules exactly as Macarchy writes them are adopted as floating apps")
    func adoption() throws {
        let live = try WindowRules.liveRules(
            CommandResult(
                command: "rules", status: 0,
                stdout: """
                    [{"index":0,"label":"float_persist_Messages","app":"^Messages$","title":""},
                     {"index":1,"label":"float_persist_App (Preview)","app":"^App \\\\(Preview\\\\)$"},
                     {"index":2,"label":"float_persist_x","app":"^Safari$","title":"^Settings"},
                     {"index":3,"label":"float_persist_Safari","app":"^Safari$","title":"^Settings"},
                     {"index":4,"label":"float_persist_y","app":"^(Notes|Calculator)$"},
                     {"index":5,"label":"float_persist_z"},
                     {"index":6,"label":"float_persist_Notes","app":"^Notes$|^Calculator$"},
                     {"index":7,"label":"other","app":"^Finder$"}]
                    """))
        #expect(
            WindowRules.floatingApps(saved: ["Calculator"], live: live)
                == ["Calculator", "Messages", "App (Preview)"])
    }

    @Test("a failed apply that changed nothing reports no rollback")
    func nothingChanged() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update { $0.floatingApps = ["Messages"] }
        let before = try Data(contentsOf: store.url)
        let spy = RuleSpy(list: "[]", failListAfter: 1)
        do {
            try await WindowRules.commitCustom(
                [CustomWindowRule(app: "Finder")], store: store,
                integrations: Integrations(execute: spy.run))
            Issue.record("Expected failure")
        } catch {
            #expect(!error.localizedDescription.contains("Restoring the previous rules"))
            #expect(error.localizedDescription.contains("yabai stopped"))
        }
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await spy.calls.allSatisfy { $0.contains("--list") })
    }

    @Test("a failed toggle replays the previous rules and toggles the window back")
    func toggleRollback() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        let custom = CustomWindowRule(app: "Finder")
        try store.update {
            $0.floatingApps = ["Messages"]; $0.windowRules = [custom]
        }
        let before = try Data(contentsOf: store.url)
        let spy = RuleSpy(
            list: #"[{"index":0,"label":"float_persist_Messages","app":"^Messages$"}]"#,
            rejectApp: "app=^Notes$",
            window: #"{"id":42,"app":"Notes","is-floating":false}"#)
        await #expect(throws: ConfigurationError.self) {
            try await WindowRules.toggle(store: store, integrations: Integrations(execute: spy.run))
        }
        #expect(try Data(contentsOf: store.url) == before)
        let calls = await spy.calls
        let flips = calls.filter { $0 == ["-m", "window", "42", "--toggle", "float"] }
        #expect(flips.count == 2)
        let replay = try #require(calls.lastIndex { $0.contains("label=float_persist_Messages") })
        #expect(calls.last == ["-m", "window", "42", "--toggle", "float"])
        #expect(calls.lastIndex(of: custom.arguments).map { $0 > replay } == true)
    }

    @Test("a toggle whose replay also fails says recovery is needed")
    func toggleRollbackFailure() async throws {
        let root = try temporary(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update { $0.floatingApps = ["Messages"] }
        let before = try Data(contentsOf: store.url)
        let spy = RuleSpy(
            list: "[]", rejectApp: "manage=off",
            window: #"{"id":7,"app":"Notes","is-floating":false}"#)
        do {
            try await WindowRules.toggle(store: store, integrations: Integrations(execute: spy.run))
            Issue.record("Expected failure")
        } catch {
            #expect(error.localizedDescription.contains("Restoring the previous rules also failed"))
        }
        #expect(try Data(contentsOf: store.url) == before)
        #expect(await spy.calls.last == ["-m", "window", "7", "--toggle", "float"])
    }
}

private actor RuleSpy {
    var calls: [[String]] = []
    let list: String
    let rejectApp: String?
    /// How many rule lists succeed before yabai stops answering.
    let failListAfter: Int?
    let window: String?
    private var lists = 0
    init(
        list: String, rejectApp: String? = nil, failListAfter: Int? = nil, window: String? = nil
    ) {
        self.list = list; self.rejectApp = rejectApp
        self.failListAfter = failListAfter; self.window = window
    }
    func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        calls.append(arguments)
        if arguments.contains("--list") {
            lists += 1
            if let failListAfter, lists > failListAfter {
                return CommandResult(command: "mock", status: 1, stderr: "yabai stopped")
            }
            return CommandResult(command: "mock", status: 0, stdout: list)
        }
        if arguments.starts(with: ["-m", "query", "--windows"]), let window {
            return CommandResult(command: "mock", status: 0, stdout: window)
        }
        if let rejectApp, arguments.contains(rejectApp) {
            return CommandResult(command: "mock", status: 1, stderr: "Rejected")
        }
        return CommandResult(command: "mock", status: 0)
    }
}
