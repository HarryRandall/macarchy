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
        try await OperationLock.run {
            let store = SettingsStore()
            let previous = try store.read()
            do {
                try await apply(
                    apps, customRules: previous.windowRules ?? [], integrations: integrations)
                try store.update { $0.floatingApps = apps.sorted() }
            } catch {
                try? await apply(
                    previous.floatingApps, customRules: previous.windowRules ?? [],
                    integrations: integrations)
                throw error
            }
        }
    }

    public static func commitCustom(
        _ rules: [CustomWindowRule], store: SettingsStore = SettingsStore(),
        integrations: Integrations = Integrations()
    ) async throws {
        try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
            let previous = try store.read()
            var candidate = previous
            candidate.windowRules = rules
            try candidate.validate()
            do {
                try await apply(
                    previous.floatingApps, customRules: rules, integrations: integrations)
                try store.update { $0.windowRules = rules }
            } catch {
                try? await apply(
                    previous.floatingApps, customRules: previous.windowRules ?? [],
                    integrations: integrations)
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
            var apps = settings.floatingApps
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
