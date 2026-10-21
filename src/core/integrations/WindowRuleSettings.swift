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
    /// Why yabai's live rules could not be read. Only saved rules are shown, and edits
    /// cannot apply until yabai responds, because they apply through it before saving.
    public let unavailableReason: String?
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

    /// Never writes. Throws only when the saved settings or yabai's reply cannot be read.
    public func read() async throws -> WindowRuleSnapshot {
        let saved = try store.read()
        let response = await integrations.yabaiRules()
        guard response.ok else {
            return WindowRuleSnapshot(
                floatingApps: saved.floatingApps, customRules: saved.windowRules ?? [],
                externalRules: [], unavailableReason: Self.reason(for: response))
        }
        let live = try WindowRules.liveRules(response)
        let floatingApps = WindowRules.floatingApps(saved: saved.floatingApps, live: live)
        let external = live.compactMap { rule -> WindowRuleSnapshot.External? in
            let label = rule.label ?? ""
            let name = WindowRules.unanchor(rule.app ?? "")
            guard !label.hasPrefix("float_persist_"), !label.hasPrefix("macarchy_custom_"),
                !(label.isEmpty && saved.floatingApps.contains(name))
            else { return nil }
            return WindowRuleSnapshot.External(app: name, title: rule.title ?? "")
        }
        return WindowRuleSnapshot(
            floatingApps: floatingApps, customRules: saved.windowRules ?? [],
            externalRules: external, unavailableReason: nil)
    }

    /// `existing` is true when the editor opened a saved rule. If that rule has since been
    /// removed elsewhere, saving fails rather than quietly bringing it back.
    public func save(_ rule: CustomWindowRule, existing: Bool = false) async throws {
        let rule = CustomWindowRule(id: rule.id, app: rule.app, title: rule.title)
        try rule.validate()
        try await WindowRules.commitCustom(store: store, integrations: integrations) { saved in
            var saved = saved
            if let index = saved.firstIndex(where: { $0.id == rule.id }) {
                saved[index] = rule
            } else if existing {
                throw ConfigurationError(
                    "This rule was removed elsewhere. Close the editor and try again.")
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

    private static func reason(for failure: CommandResult) -> String {
        let editing = "Editing is off because rules apply through yabai."
        guard FileManager.default.isExecutableFile(atPath: Paths.yabai) else {
            return "yabai isn't installed, so these are your saved rules. \(editing)"
        }
        let detail = failure.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = "yabai isn't responding, so these are your saved rules. \(editing)"
        return detail.isEmpty ? base : "\(base) \(detail)"
    }
}
