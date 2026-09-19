import Foundation
import Observation
import Macarchy

/// Per-app window rules.
///
/// Two sources that have to be shown as one list: `float_state.json` (a flat
/// array the app owns) and `yabai -m rule --list` (what is actually loaded,
/// including rules declared by hand in yabairc). The `float_persist_` label is
/// what distinguishes them — sync_float_rules.sh removes every rule carrying it
/// and re-adds from the JSON, so the app writes the file and calls the script
/// rather than reimplementing that reconciliation.
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
            case declared  // hand-written in yabairc's keep region
        }
    }

    private(set) var rules: [Rule] = []
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
        do { owned = try Self.loadFloatState() } catch {
            log.note("Window rules unreadable", error.localizedDescription); return
        }
        let result = await backend.yabaiRules()

        var built: [Rule] = []
        if result.ok, let data = result.stdout.data(using: .utf8),
            let live = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            for entry in live {
                let label = entry["label"] as? String ?? ""
                let pattern = entry["app"] as? String ?? ""
                let name = Self.unanchor(pattern)
                let isOwned = label.hasPrefix(Self.managedLabelPrefix) || owned.contains(name)
                built.append(
                    Rule(
                        id: label.isEmpty ? pattern : label,
                        app: name,
                        title: (entry["title"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                        managed: (entry["manage"] as? Bool) ?? true,
                        source: isOwned ? .floatState : .declared))
            }
        }

        // Anything in the JSON that yabai hasn't loaded yet still belongs on screen.
        for name in owned where !built.contains(where: { $0.app == name }) {
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

    func add(_ appName: String) async {
        var owned: [String]
        do { owned = try Self.loadFloatState() } catch {
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
        } catch { log.note("Window rules unreadable", error.localizedDescription) }
    }

    private func write(_ apps: [String], note: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            _ = try SettingsStore().read()
            try await WindowRules.commit(apps, integrations: backend)
        } catch { log.note("Window rules failed", error.localizedDescription) }
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
