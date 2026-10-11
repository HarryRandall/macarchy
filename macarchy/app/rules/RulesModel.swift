import Foundation
import Observation
import Macarchy

/// Saved app preferences and custom title filters, alongside externally loaded rules.
@MainActor
@Observable
final class RulesModel {
    struct Rule: Identifiable, Sendable {
        let id: String
        let app: String
        let title: String?
        let managed: Bool  // false = yabai won't tile it
        let source: Source

        enum Source: Sendable {
            case floatState  // app-owned, editable here
            case custom
            case declared  // managed outside the app
        }
    }

    private(set) var rules: [Rule] = []
    private(set) var customRules: [CustomWindowRule] = []
    private(set) var lastError: String?
    private(set) var isBusy = false

    private let backend: Integrations
    private let log: CommandLog

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    private static let managedLabelPrefix = "float_persist_"

    func reload() async {
        let owned: [String]
        do {
            let settings = try SettingsStore().read()
            owned = settings.floatingApps
            customRules = settings.windowRules ?? []
        } catch {
            lastError = error.localizedDescription
            log.note("Window rules unreadable", error.localizedDescription); return
        }
        let result = await backend.yabaiRules()

        guard result.ok else {
            lastError = result.summary
            return
        }
        guard let data = result.stdout.data(using: .utf8),
            let live = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            lastError = "The window manager returned an unreadable rules list."
            return
        }
        var built: [Rule] = []
        for entry in live {
            let label = entry["label"] as? String ?? ""
            let pattern = entry["app"] as? String ?? ""
            let name = Self.unanchor(pattern)
            let isOwned =
                label.hasPrefix(Self.managedLabelPrefix)
                || (label.isEmpty && owned.contains(name))
            built.append(
                Rule(
                    id: label.isEmpty ? pattern : label,
                    app: name,
                    title: (entry["title"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                    managed: (entry["manage"] as? Bool) ?? true,
                    source: label.hasPrefix("macarchy_custom_")
                        ? .custom : isOwned ? .floatState : .declared))
        }

        lastError = nil
        // Anything in the JSON that yabai hasn't loaded yet still belongs on screen.
        for name in owned
        where !built.contains(where: { $0.app == name && $0.source == .floatState }) {
            built.append(
                Rule(
                    id: "pending-\(name)", app: name, title: nil,
                    managed: false, source: .floatState))
        }

        // App-owned rules first, then alphabetical within each group.
        rules = built.sorted { left, right in
            let leftRank = left.source == .floatState ? 0 : 1
            let rightRank = right.source == .floatState ? 0 : 1
            if leftRank != rightRank { return leftRank < rightRank }
            return left.app.lowercased() < right.app.lowercased()
        }
    }

    func saveCustom(_ rule: CustomWindowRule) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            var saved = try SettingsStore().read().windowRules ?? []
            if let index = saved.firstIndex(where: { $0.id == rule.id }) {
                saved[index] = rule
            } else {
                saved.append(rule)
            }
            try await WindowRules.commitCustom(saved, integrations: backend)
            await reload()
            return true
        } catch {
            lastError = error.localizedDescription
            log.note("Window rule failed", error.localizedDescription)
            return false
        }
    }

    func removeCustom(_ rule: CustomWindowRule) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let saved = try SettingsStore().read().windowRules ?? []
            try await WindowRules.commitCustom(
                saved.filter { $0.id != rule.id }, integrations: backend)
            await reload()
        } catch {
            lastError = error.localizedDescription
            log.note("Window rule failed", error.localizedDescription)
        }
    }

    func add(_ appName: String) async {
        var owned: [String]
        do { owned = try Self.loadFloatState() } catch {
            lastError = error.localizedDescription
            log.note("Window rules unreadable", error.localizedDescription); return
        }
        guard !owned.contains(appName) else { return }
        owned.append(appName)
        await write(owned, note: "added \(appName)")
    }

    func remove(_ rule: Rule) async {
        guard rule.source == .floatState else { return }
        do {
            let owned = try Self.loadFloatState().filter { $0 != rule.app }
            await write(owned, note: "removed \(rule.app)")
        } catch {
            lastError = error.localizedDescription
            log.note("Window rules unreadable", error.localizedDescription)
        }
    }

    private func write(_ apps: [String], note: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            _ = try SettingsStore().read()
            try await WindowRules.commit(apps, integrations: backend)
        } catch {
            lastError = error.localizedDescription
            log.note("Window rules failed", error.localizedDescription)
            return
        }
        await reload()
    }

    private static func loadFloatState() throws -> [String] {
        try SettingsStore().read().floatingApps
    }

    /// "^System Settings$" → "System Settings".
    static func unanchor(_ pattern: String) -> String {
        var name = pattern
        if name.hasPrefix("^") { name.removeFirst() }
        if name.hasSuffix("$") { name.removeLast() }
        return name.replacingOccurrences(of: "\\", with: "")
    }
}
