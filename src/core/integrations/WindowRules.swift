import Foundation

public enum WindowRules {
    public static func apply(
        _ apps: [String], customRules: [CustomWindowRule] = [],
        integrations: Integrations = Integrations()
    ) async throws {
        for rule in customRules { try rule.validate() }
        struct Rule: Decodable { var index: Int; var label: String? }
        let response = await integrations.yabaiRules()
        guard response.ok else { throw ConfigurationError(response.summary) }
        let rules = try JSONDecoder().decode([Rule].self, from: Data(response.stdout.utf8))
        for rule in rules.filter({
            $0.label?.hasPrefix("float_persist_") == true
                || $0.label?.hasPrefix("macarchy_custom_") == true
        }).sorted(by: {
            $0.index > $1.index
        }) {
            let result = await integrations.execute(
                Paths.yabai, ["-m", "rule", "--remove", String(rule.index)])
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
        for app in apps.sorted() {
            let pattern = NSRegularExpression.escapedPattern(for: app)
            let result = await integrations.execute(
                Paths.yabai,
                [
                    "-m", "rule", "--add", "app=^\(pattern)$", "manage=off",
                    "label=float_persist_\(app)"
                ])
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
        for rule in customRules {
            let result = await integrations.execute(Paths.yabai, rule.arguments)
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
    }
}

extension WindowRules {
    private struct Window: Decodable {
        let id: Int
        let app: String
        let floating: Bool
        enum CodingKeys: String, CodingKey { case id, app; case floating = "is-floating" }
    }

    public static func commit(
        _ apps: [String], integrations: Integrations = Integrations()
    ) async throws {
        try await commit(integrations: integrations) { _ in apps }
    }

    struct LiveRule: Decodable {
        let label: String?
        let app: String?
        let title: String?
    }

    static func liveRules(_ response: CommandResult) throws -> [LiveRule] {
        do {
            return try JSONDecoder().decode([LiveRule].self, from: Data(response.stdout.utf8))
        } catch {
            throw ConfigurationError("The window manager returned an unreadable rules list.")
        }
    }

    /// The saved floating apps plus any that float only through a live `float_persist_`
    /// rule, added by an older version, by hand or by the classic window. Reads show this
    /// list and edits start from it, so an unrelated edit adopts those apps instead of
    /// removing their rules.
    static func floatingApps(saved: [String], live: [LiveRule]) -> [String] {
        var apps = saved
        for rule in live where rule.label?.hasPrefix("float_persist_") == true {
            let name = unanchor(rule.app ?? "")
            if !name.isEmpty, !apps.contains(name) { apps.append(name) }
        }
        return apps
    }

    static func unanchor(_ pattern: String) -> String {
        var name = pattern
        if name.hasPrefix("^") { name.removeFirst() }
        if name.hasSuffix("$") { name.removeLast() }
        return name.replacingOccurrences(of: "\\", with: "")
    }

    private static func floatingApps(
        saved: [String], integrations: Integrations
    ) async throws -> [String] {
        let response = await integrations.yabaiRules()
        guard response.ok else { throw ConfigurationError(response.summary) }
        return floatingApps(saved: saved, live: try liveRules(response))
    }

    public static func commit(
        store: SettingsStore = SettingsStore(), integrations: Integrations = Integrations(),
        edit: @escaping @Sendable ([String]) -> [String]
    ) async throws {
        try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
            let previous = try store.read()
            let current = try await floatingApps(
                saved: previous.floatingApps, integrations: integrations)
            let apps = edit(current).sorted()
            var candidate = previous
            candidate.floatingApps = apps
            try candidate.validate()
            do {
                try await apply(
                    apps, customRules: previous.windowRules ?? [], integrations: integrations)
                try store.update { $0.floatingApps = apps }
            } catch {
                do {
                    try await apply(
                        current, customRules: previous.windowRules ?? [],
                        integrations: integrations)
                } catch let rollback {
                    throw ConfigurationError(
                        "\(error.localizedDescription) Restoring the previous rules also failed: "
                            + "\(rollback.localizedDescription). Reapply rules to recover.")
                }
                throw error
            }
        }
    }

    public static func commitCustom(
        _ rules: [CustomWindowRule], store: SettingsStore = SettingsStore(),
        integrations: Integrations = Integrations()
    ) async throws {
        try await commitCustom(store: store, integrations: integrations) { _ in rules }
    }

    /// Edits the saved rules inside the lock, so two edits made at once cannot
    /// each start from the same list and drop the other's change.
    public static func commitCustom(
        store: SettingsStore = SettingsStore(),
        integrations: Integrations = Integrations(),
        edit: @escaping @Sendable ([CustomWindowRule]) throws -> [CustomWindowRule]
    ) async throws {
        try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
            let previous = try store.read()
            let rules = try edit(previous.windowRules ?? [])
            let apps = try await floatingApps(
                saved: previous.floatingApps, integrations: integrations
            ).sorted()
            var candidate = previous
            candidate.floatingApps = apps
            candidate.windowRules = rules
            try candidate.validate()
            do {
                try await apply(apps, customRules: rules, integrations: integrations)
                try store.update {
                    $0.floatingApps = apps
                    $0.windowRules = rules
                }
            } catch {
                do {
                    try await apply(
                        apps, customRules: previous.windowRules ?? [],
                        integrations: integrations)
                } catch let rollback {
                    throw ConfigurationError(
                        "\(error.localizedDescription) Restoring the previous rules also failed: "
                            + "\(rollback.localizedDescription). Reapply rules to recover.")
                }
                throw error
            }
        }
    }

    public static func windowCreated(integrations: Integrations = Integrations()) async throws {
        guard let id = ProcessInfo.processInfo.environment["YABAI_WINDOW_ID"], Int(id) != nil else {
            return
        }
        let result = await integrations.execute(
            Paths.yabai, ["-m", "query", "--windows", "--window", id])
        guard result.ok else { throw ConfigurationError(result.summary) }
        let window = try JSONDecoder().decode(Window.self, from: Data(result.stdout.utf8))
        guard try SettingsStore().read().floatingApps.contains(window.app), !window.floating else {
            return
        }
        let applied = await integrations.execute(
            Paths.yabai, ["-m", "window", id, "--toggle", "float"])
        guard applied.ok else { throw ConfigurationError(applied.summary) }
    }

    public static func toggle(integrations: Integrations = Integrations()) async throws {
        try await OperationLock.run {
            let store = SettingsStore()
            let settings = try store.read()
            var apps = try await floatingApps(
                saved: settings.floatingApps, integrations: integrations)
            let result = await integrations.execute(
                Paths.yabai, ["-m", "query", "--windows", "--window"])
            guard result.ok else { throw ConfigurationError(result.summary) }
            let window = try JSONDecoder().decode(Window.self, from: Data(result.stdout.utf8))
            let applied = await integrations.execute(
                Paths.yabai, ["-m", "window", String(window.id), "--toggle", "float"])
            guard applied.ok else { throw ConfigurationError(applied.summary) }
            apps.removeAll { $0 == window.app }
            if !window.floating { apps.append(window.app) }
            try await apply(
                apps, customRules: settings.windowRules ?? [], integrations: integrations)
            try store.update { $0.floatingApps = apps.sorted() }
        }
    }
}
