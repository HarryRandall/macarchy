import Foundation

public enum WindowRules {
    public static func apply(
        _ apps: [String], customRules: [CustomWindowRule] = [],
        integrations: Integrations = Integrations()
    ) async throws {
        var changed = false
        try await apply(
            apps, customRules: customRules, integrations: integrations, changed: &changed)
    }

    /// `changed` is set before the first command that edits yabai's rules, so a
    /// failure that leaves it false has changed nothing and needs no replay.
    private static func apply(
        _ apps: [String], customRules: [CustomWindowRule], integrations: Integrations,
        changed: inout Bool
    ) async throws {
        for rule in customRules { try rule.validate() }
        let owned = try await liveRules(integrations).filter {
            ownedFloatingApp($0) != nil || $0.label?.hasPrefix("macarchy_custom_") == true
        }
        for index in owned.compactMap(\.index).sorted(by: >) {
            changed = true
            let result = await integrations.execute(
                Paths.yabai, ["-m", "rule", "--remove", String(index)])
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
        for app in apps.sorted() {
            changed = true
            let result = await integrations.execute(
                Paths.yabai,
                [
                    "-m", "rule", "--add", "app=\(floatingPattern(app))", "manage=off",
                    "label=\(floatingPrefix)\(app)"
                ])
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
        for rule in customRules {
            changed = true
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
        let index: Int?
        let label: String?
        let app: String?
        let title: String?
    }

    static let floatingPrefix = "float_persist_"

    static func floatingPattern(_ app: String) -> String {
        "^\(NSRegularExpression.escapedPattern(for: app))$"
    }

    /// yabai's current rules. Every edit lists them before changing anything,
    /// so a stopped or missing yabai is reported plainly as changing nothing
    /// rather than as a failed edit.
    private static func liveRules(_ integrations: Integrations) async throws -> [LiveRule] {
        let response = await integrations.yabaiRules()
        guard response.ok else {
            let detail = response.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ConfigurationError(
                "yabai is not running or could not list its rules, so nothing was changed."
                    + (detail.isEmpty ? "" : " \(detail)"))
        }
        return try liveRules(response)
    }

    static func liveRules(_ response: CommandResult) throws -> [LiveRule] {
        do {
            return try JSONDecoder().decode([LiveRule].self, from: Data(response.stdout.utf8))
        } catch {
            throw ConfigurationError("The window manager returned an unreadable rules list.")
        }
    }

    /// The app a `float_persist_` rule floats, when the rule is exactly what
    /// `apply` writes for that app. Anything else with the prefix, such as a
    /// rule with a title, a pattern matching several apps or no app at all,
    /// was written by hand and cannot be represented as a floating app, so it
    /// is shown as external and never removed or rewritten.
    static func ownedFloatingApp(_ rule: LiveRule) -> String? {
        guard let label = rule.label, label.hasPrefix(floatingPrefix) else { return nil }
        let name = String(label.dropFirst(floatingPrefix.count))
        guard !name.isEmpty, rule.app == floatingPattern(name), (rule.title ?? "").isEmpty
        else { return nil }
        return name
    }

    /// The saved floating apps plus any that float only through a live `float_persist_`
    /// rule, added by an older version or by the classic window. Reads show this list
    /// and edits start from it, so an unrelated edit adopts those apps instead of
    /// removing their rules.
    static func floatingApps(saved: [String], live: [LiveRule]) -> [String] {
        var apps = saved
        for name in live.compactMap(ownedFloatingApp) where !apps.contains(name) {
            apps.append(name)
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
        floatingApps(saved: saved, live: try await liveRules(integrations))
    }

    /// Applies the new rules, then saves them. If either fails, the previous
    /// rules are applied again and `undo` reverses anything else the caller
    /// changed, so yabai never keeps rules the settings do not hold.
    private static func applyAndSave(
        _ apps: [String], customRules: [CustomWindowRule],
        restoring previous: (apps: [String], rules: [CustomWindowRule]),
        integrations: Integrations,
        save: () throws -> Void,
        undo: () async throws -> Void = {}
    ) async throws {
        var changed = false
        do {
            try await apply(
                apps, customRules: customRules, integrations: integrations, changed: &changed)
            try save()
        } catch {
            var failures: [String] = []
            if changed {
                do {
                    try await apply(
                        previous.apps, customRules: previous.rules, integrations: integrations)
                } catch let rollback {
                    failures.append(rollback.localizedDescription)
                }
            }
            do { try await undo() } catch let rollback {
                failures.append(rollback.localizedDescription)
            }
            guard failures.isEmpty else {
                throw ConfigurationError(
                    "\(error.localizedDescription) Restoring the previous rules also failed: "
                        + "\(failures.joined(separator: " ")). Reapply rules to recover.")
            }
            throw error
        }
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
            let rules = previous.windowRules ?? []
            try await applyAndSave(
                apps, customRules: rules, restoring: (current, rules), integrations: integrations,
                save: { try store.update { $0.floatingApps = apps } })
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
            try await applyAndSave(
                apps, customRules: rules, restoring: (apps, previous.windowRules ?? []),
                integrations: integrations,
                save: {
                    try store.update {
                        $0.floatingApps = apps
                        $0.windowRules = rules
                    }
                })
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

    public static func toggle(
        store: SettingsStore = SettingsStore(), integrations: Integrations = Integrations()
    ) async throws {
        try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
            let settings = try store.read()
            let current = try await floatingApps(
                saved: settings.floatingApps, integrations: integrations)
            let result = await integrations.execute(
                Paths.yabai, ["-m", "query", "--windows", "--window"])
            guard result.ok else { throw ConfigurationError(result.summary) }
            let window = try JSONDecoder().decode(Window.self, from: Data(result.stdout.utf8))
            let flip = ["-m", "window", String(window.id), "--toggle", "float"]
            let applied = await integrations.execute(Paths.yabai, flip)
            guard applied.ok else { throw ConfigurationError(applied.summary) }
            let others = current.filter { $0 != window.app }
            let apps = (window.floating ? others : others + [window.app]).sorted()
            let rules = settings.windowRules ?? []
            try await applyAndSave(
                apps, customRules: rules, restoring: (current, rules), integrations: integrations,
                save: { try store.update { $0.floatingApps = apps } },
                undo: {
                    let back = await integrations.execute(Paths.yabai, flip)
                    guard back.ok else { throw ConfigurationError(back.summary) }
                })
        }
    }
}
