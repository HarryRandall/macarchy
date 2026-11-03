import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

/// Holds the host's half of the bridge to `tests/fixtures/bridge`, which
/// `src/desktop/ui/src/bridge/fixtures.ts` writes from the TypeScript contract.
/// A method, field, enum value or explicit null changed on one side only fails
/// either here or in Vitest.
@MainActor
struct BridgeContractFixtureTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "fixtures/bridge")

    @Test("the two surfaces register exactly the methods methods.json names")
    func methodNames() throws {
        let registered = Set(registeredMethods().keys)
        let named = Set(try Self.cases(in: "methods.json").keys)
        let unnamed = registered.subtracting(named).sorted()
        let unregistered = named.subtracting(registered).sorted()
        #expect(unnamed.isEmpty, "Registered in Swift but missing from methods.json: \(unnamed)")
        #expect(
            unregistered.isEmpty,
            "In methods.json but registered by neither surface: \(unregistered)")
    }

    @Test("every method's params decode and its result round-trips to the fixture")
    func methodShapes() throws {
        let contract = registeredMethods()
        for (method, cases) in try Self.cases(in: "methods.json").sorted(by: { $0.key < $1.key }) {
            guard let types = contract[method] else { continue }
            for (index, fixture) in cases.enumerated() {
                let label = "\(method) case \(index + 1)"
                checkParams(fixture["params"], as: types.params, label: label)
                checkResult(fixture["result"], as: types.result, label: label)
            }
        }
    }

    @Test("every event's state round-trips through its constructor to the fixture")
    func eventShapes() throws {
        let fixtures = try Self.cases(in: "events.json")
        let builders = Self.eventBuilders()
        #expect(
            Set(builders.keys) == Set(fixtures.keys),
            "The event table in this test and events.json name different events")
        for (type, cases) in fixtures.sorted(by: { $0.key < $1.key }) {
            guard let build = builders[type] else { continue }
            for (index, fixture) in cases.enumerated() {
                let label = "\(type) case \(index + 1)"
                do {
                    let event = try build(fixture["state"])
                    let encoded = try FixtureJSON.object(JSONEncoder().encode(event))
                    Self.compare(encoded, fixture, label: label)
                } catch {
                    Issue.record("\(label) state does not decode: \(error)")
                }
            }
        }
    }

    /// Both pages' routers, built as the app builds them. Registering only
    /// stores handlers, so nothing here reaches the desktop.
    private func registeredMethods() -> [String: BridgeRouter.Types] {
        _ = NSApplication.shared
        let store = SettingsStore(
            url: FileManager.default.temporaryDirectory
                .appending(path: "bridge-contract-\(UUID())/settings.json"))
        let model = AppModel(
            backend: Integrations { _, _ in
                Issue.record("Checking the bridge contract must not run anything.")
                return CommandResult(command: "unexpected", status: 1)
            }, settingsStore: store)
        let settings = WebSurface(surface: .settings)
        SettingsWindow.registerFeatures(on: settings, model: model)
        let switcher = WebSurface(surface: .switcher)
        ThemeSwitcher().registerMethods(on: switcher, model: model)
        var merged = settings.router.contract
        for (method, types) in switcher.router.contract {
            if let shared = merged[method] {
                #expect(
                    ObjectIdentifier(shared.params) == ObjectIdentifier(types.params)
                        && ObjectIdentifier(shared.result) == ObjectIdentifier(types.result),
                    "\(method) takes or returns different types on the two surfaces")
            }
            merged[method] = types
        }
        return merged
    }

    /// Each event type with the state its constructor takes, built through
    /// that constructor so the type string is checked as well.
    private static func eventBuilders() -> [String: (Any?) throws -> BridgeEvent] {
        typealias JSON = FixtureJSON
        return [
            "shell.changed": { try .shellChanged(JSON.decode(ShellState.self, $0)) },
            "shell.logChanged": { _ in .shellLogChanged },
            "shell.shortcut": {
                try .shellShortcut(JSON.decode(ShellShortcutState.self, $0).shortcut)
            },
            "layout.changed": { try .layoutChanged(JSON.decode(LayoutState.self, $0)) },
            "themes.changed": { try .themesChanged(JSON.decode(SwitcherState.self, $0)) },
            "switcher.willOpen": {
                let opening = try JSON.decode(SwitcherOpening.self, $0)
                return .switcherWillOpen(opening.state, error: opening.error)
            },
            "switcher.didClose": { _ in .switcherDidClose },
            "rules.changed": { try .rulesChanged(JSON.decode(RulesState.self, $0)) },
            "rules.unavailable": {
                try .rulesUnavailable(JSON.decode(RulesUnavailable.self, $0).message)
            },
            "advanced.changed": { try .advancedChanged(JSON.decode(AdvancedState.self, $0)) },
            "advanced.invalidated": { _ in .advancedInvalidated },
            "setup.progress": { try .setupProgress(JSON.decode(SetupProgress.self, $0)) },
            "borders.changed": { try .bordersChanged(JSON.decode(BordersState.self, $0)) },
            "menuBar.changed": { _ in BridgeEvent("menuBar.changed") },
            "home.changed": { _ in .homeChanged },
            "health.changed": { _ in .healthChanged },
            "report.invalidated": { _ in .reportInvalidated },
            "shortcuts.changed": { try .shortcutsChanged(JSON.decode(ShortcutsState.self, $0)) },
            "shortcuts.unavailable": { try .shortcutsUnavailable(JSON.decode(String.self, $0)) }
        ]
    }

    /// `Empty` and other params types that are also `Encodable` must encode
    /// back to the fixture; the rest only have to decode.
    private func checkParams(_ value: Any?, as type: any Decodable.Type, label: String) {
        guard let value else {
            Issue.record("\(label) has no params")
            return
        }
        do {
            if let codable = type as? any Codable.Type {
                let encoded = try FixtureJSON.roundTrip(codable, value)
                Self.compare(encoded, value, label: "\(label) params")
            } else {
                try FixtureJSON.decodeOnly(type, value)
            }
        } catch {
            Issue.record("\(label) params do not decode as \(type): \(error)")
        }
    }

    private func checkResult(_ value: Any?, as type: any Encodable.Type, label: String) {
        guard let value else {
            Issue.record("\(label) has no result")
            return
        }
        guard let codable = type as? any Codable.Type else {
            Issue.record("\(label): \(type) must be Decodable too, so its fixture can be read")
            return
        }
        do {
            let encoded = try FixtureJSON.roundTrip(codable, value)
            Self.compare(encoded, value, label: "\(label) result")
        } catch {
            Issue.record("\(label) result does not decode as \(type): \(error)")
        }
    }

    /// Each name in a fixture file with its cases.
    private static func cases(in file: String) throws -> [String: [[String: Any]]] {
        let data = try Data(contentsOf: fixtures.appending(path: file))
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
            "\(file) should map each name to a list of cases")
    }

    private static func compare(_ actual: Any, _ expected: Any, label: String) {
        if let difference = FixtureJSON.difference(actual, expected, at: label) {
            Issue.record(Comment(rawValue: difference))
        }
    }
}

/// Decoding, encoding and comparing parsed JSON for the fixture tests.
private enum FixtureJSON {
    static func roundTrip<T: Codable>(_ type: T.Type, _ value: Any) throws -> Any {
        try object(JSONEncoder().encode(JSONDecoder().decode(type, from: data(value))))
    }

    static func decodeOnly<T: Decodable>(_ type: T.Type, _ value: Any) throws {
        _ = try JSONDecoder().decode(type, from: data(value))
    }

    /// A missing state decodes as `null`, so a stateless fixture fails here
    /// rather than passing for an event that needs one.
    static func decode<T: Decodable>(_ type: T.Type, _ value: Any?) throws -> T {
        try JSONDecoder().decode(type, from: data(value ?? NSNull()))
    }

    static func data(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
    }

    static func object(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Where `actual` first differs from `expected`, or nil when they match.
    /// Booleans and numbers are told apart, which `NSNumber` equality does not.
    static func difference(_ actual: Any, _ expected: Any, at path: String) -> String? {
        switch (actual, expected) {
        case (is NSNull, is NSNull):
            return nil
        case (let actual as [String: Any], let expected as [String: Any]):
            return objectDifference(actual, expected, at: path)
        case (let actual as [Any], let expected as [Any]):
            guard actual.count == expected.count else {
                return "\(path) has \(actual.count) items; the fixture has \(expected.count)"
            }
            for (index, (item, fixture)) in zip(actual, expected).enumerated() {
                if let found = difference(item, fixture, at: "\(path)[\(index)]") { return found }
            }
            return nil
        case (let actual as NSNumber, let expected as NSNumber):
            if isBoolean(actual) == isBoolean(expected), actual == expected { return nil }
        case (let actual as String, let expected as String):
            if actual == expected { return nil }
        default:
            break
        }
        return "\(path) is \(describe(actual)); the fixture has \(describe(expected))"
    }

    private static func objectDifference(
        _ actual: [String: Any], _ expected: [String: Any], at path: String
    ) -> String? {
        for key in Set(actual.keys).union(expected.keys).sorted() {
            let here = "\(path).\(key)"
            guard let value = actual[key] else {
                return "\(here) is in the fixture but Swift leaves it out"
            }
            guard let fixture = expected[key] else {
                return "\(here) is encoded by Swift but not in the fixture"
            }
            if let found = difference(value, fixture, at: here) { return found }
        }
        return nil
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func describe(_ value: Any) -> String {
        (try? data(value)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "\(value)"
    }
}
