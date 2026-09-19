import Foundation
import Observation

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
        let managed: Bool       // false = yabai won't tile it
        let source: Source

        enum Source: Sendable {
            case floatState     // app-owned, editable here
            case declared       // hand-written in yabairc's keep region
        }
    }

    private(set) var rules: [Rule] = []
    private(set) var isBusy = false

    private let log: CommandLog
    init(log: CommandLog) { self.log = log }

    private static var stateURL: URL {
        Paths.home.appending(path: ".config/yabai/float_state.json")
    }
    private static var syncScript: String {
        Paths.home.appending(path: ".config/yabai/sync_float_rules.sh").path
    }

    private static let managedLabelPrefix = "float_persist_"

    func reload() async {
        let owned = Self.loadFloatState()
        let result = await CommandRunner.run(Paths.yabai, ["-m", "rule", "--list"])

        var built: [Rule] = []
        if result.ok, let data = result.stdout.data(using: .utf8),
           let live = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for entry in live {
                let label = entry["label"] as? String ?? ""
                let pattern = entry["app"] as? String ?? ""
                let name = Self.unanchor(pattern)
                let isOwned = label.hasPrefix(Self.managedLabelPrefix) || owned.contains(name)
                built.append(Rule(
                    id: label.isEmpty ? pattern : label,
                    app: name,
                    title: (entry["title"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                    managed: (entry["manage"] as? Bool) ?? true,
                    source: isOwned ? .floatState : .declared))
            }
        }

        // Anything in the JSON that yabai hasn't loaded yet still belongs on screen.
        for name in owned where !built.contains(where: { $0.app == name }) {
            built.append(Rule(id: "pending-\(name)", app: name, title: nil,
                              managed: false, source: .floatState))
        }

        rules = built.sorted {
            ($0.source == .floatState ? 0 : 1, $0.app.lowercased())
                < ($1.source == .floatState ? 0 : 1, $1.app.lowercased())
        }
    }

    func add(_ appName: String) async {
        var owned = Self.loadFloatState()
        guard !owned.contains(appName) else { return }
        owned.append(appName)
        await write(owned, note: "added \(appName)")
    }

    func remove(_ rule: Rule) async {
        guard rule.source == .floatState else { return }
        let owned = Self.loadFloatState().filter { $0 != rule.app }
        await write(owned, note: "removed \(rule.app)")
    }

    private func write(_ apps: [String], note: String) async {
        isBusy = true
        defer { isBusy = false }

        try? SnapshotStore().capture([Self.stateURL], reason: "float rules: \(note)")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(apps.sorted()).write(to: Self.stateURL, options: .atomic)
        } catch {
            log.note("float_state.json write failed", error.localizedDescription)
            return
        }

        // The script owns reconciliation: it strips every float_persist_ rule
        // and re-adds from the file, so partial state can't accumulate.
        log.record(await CommandRunner.run("/bin/bash", [Self.syncScript]))
        await reload()
    }

    private static func loadFloatState() -> [String] {
        guard let data = try? Data(contentsOf: stateURL),
              let apps = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return apps
    }

    /// "^System Settings$" → "System Settings".
    static func unanchor(_ pattern: String) -> String {
        var name = pattern
        if name.hasPrefix("^") { name.removeFirst() }
        if name.hasSuffix("$") { name.removeLast() }
        return name.replacingOccurrences(of: "\\", with: "")
    }
}
