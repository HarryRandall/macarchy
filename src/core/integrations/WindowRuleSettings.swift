import Foundation

/// Saved rules and the live rules managed outside Macarchy. Reading never applies rules.
public struct WindowRuleSnapshot: Sendable, Equatable {
    public struct External: Codable, Sendable, Equatable {
        public let app: String
        public let title: String
    }

    public let floatingApps: [String]
    public let customRules: [CustomWindowRule]
    public let externalRules: [External]
}

/// Shared rule operations for settings interfaces. Edits read the latest settings inside the lock.
public struct WindowRuleSettings: Sendable {
    private let store: SettingsStore
    private let integrations: Integrations

    public init(store: SettingsStore = SettingsStore(), integrations: Integrations = Integrations())
    {
        self.store = store
        self.integrations = integrations
    }

    public func read() async throws -> WindowRuleSnapshot {
        let saved = try store.read()
        let response = await integrations.yabaiRules()
        guard response.ok else { throw ConfigurationError(response.summary) }
        struct LiveRule: Decodable {
            let label: String?
            let app: String?
            let title: String?
        }
        let live: [LiveRule]
        do {
            live = try JSONDecoder().decode([LiveRule].self, from: Data(response.stdout.utf8))
        } catch {
            throw ConfigurationError("The window manager returned an unreadable rules list.")
        }
        var floatingApps = saved.floatingApps
        for rule in live where rule.label?.hasPrefix("float_persist_") == true {
            let name = Self.unanchor(rule.app ?? "")
            if !floatingApps.contains(name) { floatingApps.append(name) }
        }
        let external = live.compactMap { rule -> WindowRuleSnapshot.External? in
            let label = rule.label ?? ""
            let name = Self.unanchor(rule.app ?? "")
            guard !label.hasPrefix("float_persist_"), !label.hasPrefix("macarchy_custom_"),
                !(label.isEmpty && saved.floatingApps.contains(name))
            else { return nil }
            return WindowRuleSnapshot.External(app: name, title: rule.title ?? "")
        }
        return WindowRuleSnapshot(
            floatingApps: floatingApps, customRules: saved.windowRules ?? [],
            externalRules: external)
    }

    public func save(_ rule: CustomWindowRule) async throws {
        let rule = CustomWindowRule(id: rule.id, app: rule.app, title: rule.title)
        try rule.validate()
        try await WindowRules.commitCustom(store: store, integrations: integrations) { saved in
            var saved = saved
            if let index = saved.firstIndex(where: { $0.id == rule.id }) {
                saved[index] = rule
            } else {
                saved.append(rule)
            }
            return saved
        }
    }

    public func removeCustom(id: String) async throws {
        guard UUID(uuidString: id) != nil else {
            throw ConfigurationError("Invalid rule identifier")
        }
        try await WindowRules.commitCustom(store: store, integrations: integrations) {
            $0.filter { $0.id != id }
        }
    }

    public func setFloating(app: String, floating: Bool) async throws {
        let name = app.trimmingCharacters(in: .whitespacesAndNewlines)
        try CustomWindowRule(app: name).validate()
        try await WindowRules.commit(store: store, integrations: integrations) { saved in
            var apps = saved.filter { $0 != name }
            if floating { apps.append(name) }
            return apps
        }
    }

    private static func unanchor(_ pattern: String) -> String {
        var name = pattern
        if name.hasPrefix("^") { name.removeFirst() }
        if name.hasSuffix("$") { name.removeLast() }
        return name.replacingOccurrences(of: "\\", with: "")
    }
}
