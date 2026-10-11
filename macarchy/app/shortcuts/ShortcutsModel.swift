import Foundation
import Observation
import Macarchy

/// Reads skhd's bindings, and rewrites the key chord on one of them.
///
/// Only the chord is editable. The command half is arbitrary shell, and a
/// settings window is the wrong place to author that — the file stays the
/// source of truth for what a shortcut *does*.
@MainActor
@Observable
final class ShortcutsModel {
    private(set) var bindings: [SkhdBinding] = []
    private(set) var isSaving = false
    var lastError: String?

    var search = ""
    /// Empty means every modifier; otherwise a binding must use all of these.
    var modifierFilter: Set<String> = []
    var sectionFilter: String?
    var scopeFilter: Scope = .all

    enum Scope: String, CaseIterable {
        case all = "All apps and scopes"
        case global = "Global shortcuts"
        case perApp = "Per-app shortcuts"
    }

    private let log: CommandLog
    init(log: CommandLog) { self.log = log }

    static var configURL: URL { Paths.home.appending(path: ".config/skhd/skhdrc") }

    func reload() {
        guard let text = try? String(contentsOf: Self.configURL, encoding: .utf8) else {
            log.note("skhdrc unreadable", Self.configURL.path)
            return
        }
        bindings = SkhdConfig.parse(text)
        log.note("parsed skhdrc", "\(bindings.count) bindings")
    }

    // MARK: - Editing

    /// Another binding already using this chord, if there is one.
    func conflict(for chord: Chord, excluding binding: SkhdBinding?) -> SkhdBinding? {
        bindings.first {
            $0.id != binding?.id
                && $0.key.lowercased() == chord.key.lowercased()
                && Set($0.modifiers.map { $0.lowercased() }) == Set(chord.modifiers)
        }
    }

    /// Rewrites one line of skhdrc, then restarts skhd so the change takes.
    ///
    /// The file is copied into the snapshot store first: this is the one place
    /// the app writes to a config a person almost certainly hand-edited.
    func rebind(_ binding: SkhdBinding, to chord: Chord, daemons: DaemonMonitor) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let url = Self.configURL
            let text = try String(contentsOf: url, encoding: .utf8)
            guard
                let updated = SkhdConfig.rebind(
                    text, line: binding.id, modifiers: Array(chord.modifiers), key: chord.key)
            else {
                lastError = "That line no longer looks like a shortcut. Reload and try again."
                return
            }
            _ = try SnapshotStore().capture([url], reason: "shortcut rebind")
            try updated.write(to: url, atomically: true, encoding: .utf8)
            log.note("rewrote skhdrc", "\(binding.keyCaps.joined()) → \(chord.caps.joined())")
            reload()
            lastError = nil
            await daemons.restart(.skhd)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Comments a binding out and restarts skhd.
    func disable(_ binding: SkhdBinding, daemons: DaemonMonitor) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let url = Self.configURL
            let text = try String(contentsOf: url, encoding: .utf8)
            guard let updated = SkhdConfig.disable(text, line: binding.id) else {
                lastError = "That line is already disabled."
                return
            }
            _ = try SnapshotStore().capture([url], reason: "shortcut disabled")
            try updated.write(to: url, atomically: true, encoding: .utf8)
            log.note("disabled shortcut", binding.keyCaps.joined())
            reload()
            lastError = nil
            await daemons.restart(.skhd)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Rows

    /// The list flattened to headers and bindings.
    ///
    /// The page draws this through one `LazyVStack` rather than a card per
    /// section, so only the rows on screen are built.
    struct Row: Identifiable {
        enum Position { case first, middle, last, only }
        enum Kind {
            case header(String, Int)
            case binding(SkhdBinding)
        }

        let id: String
        let kind: Kind
        let position: Position
    }

    var rows: [Row] {
        var result: [Row] = []
        for section in sections {
            let group = bindings(in: section)
            guard !group.isEmpty else { continue }
            if group.count > 1 {
                result.append(
                    Row(
                        id: "header-\(section)", kind: .header(section, group.count),
                        position: .only))
            }
            result.append(contentsOf: rows(for: group))
        }
        let loose = ungrouped
        if !loose.isEmpty {
            result.append(contentsOf: rows(for: loose))
        }
        return result
    }

    private func rows(for group: [SkhdBinding]) -> [Row] {
        group.enumerated().map { index, binding in
            let position: Row.Position =
                group.count == 1
                ? .only
                : index == 0 ? .first : (index == group.count - 1 ? .last : .middle)
            return Row(id: "b-\(binding.id)", kind: .binding(binding), position: position)
        }
    }

    var perAppCount: Int { bindings.count { !$0.appOverrides.isEmpty } }
    var passthroughCount: Int { bindings.count(where: \.passthrough) }

    func toggle(_ modifier: String) {
        if modifierFilter.contains(modifier) {
            modifierFilter.remove(modifier)
        } else {
            modifierFilter.insert(modifier)
        }
    }

    // MARK: - Filtering

    /// Sections in the order they appear, so the file's own grouping survives.
    var sections: [String] {
        var seen = Set<String>()
        return filtered.compactMap(\.section).filter { seen.insert($0).inserted }
    }

    /// Every section in the file, for the filter menu.
    var allSections: [String] {
        var seen = Set<String>()
        return bindings.compactMap(\.section).filter { seen.insert($0).inserted }
    }

    func bindings(in section: String) -> [SkhdBinding] {
        filtered.filter { $0.section == section }
    }

    var ungrouped: [SkhdBinding] { filtered.filter { $0.section == nil } }

    var matchCount: Int { filtered.count }

    var hasFilters: Bool {
        !search.isEmpty || !modifierFilter.isEmpty || sectionFilter != nil || scopeFilter != .all
    }

    func clearFilters() {
        search = ""
        modifierFilter = []
        sectionFilter = nil
        scopeFilter = .all
    }

    func label(for binding: SkhdBinding) -> String {
        ShortcutPresentation.label(
            binding, groupCount: bindings.count { $0.section == binding.section })
    }

    /// How many bindings use a modifier, for the filter chips.
    func count(usingModifier modifier: String) -> Int {
        bindings.filter { $0.modifiers.contains { $0.hasSuffix(modifier) } }.count
    }

    private var filtered: [SkhdBinding] {
        var result = bindings
        if scopeFilter != .all {
            result = result.filter { (scopeFilter == .perApp) == !$0.appOverrides.isEmpty }
        }

        if let sectionFilter {
            result = result.filter { $0.section == sectionFilter }
        }

        if !modifierFilter.isEmpty {
            result = result.filter { binding in
                modifierFilter.allSatisfy { wanted in
                    binding.modifiers.contains { $0.hasSuffix(wanted) }
                }
            }
        }

        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return result }
        return result.filter {
            label(for: $0).lowercased().contains(query)
                || $0.command.lowercased().contains(query)
                || $0.keyCaps.joined(separator: " ").lowercased().contains(query)
                || ($0.section?.lowercased().contains(query) ?? false)
                || $0.key.lowercased().contains(query)
        }
    }
}

/// A captured key chord, independent of any binding.
struct Chord: Equatable {
    var modifiers: Set<String>
    var key: String

    var isEmpty: Bool { key.isEmpty }

    var caps: [String] {
        let order = ["ctrl", "alt", "shift", "cmd"]
        return order.filter(modifiers.contains).map(SkhdBinding.symbol(forModifier:))
            + [SkhdBinding.display(key: key)]
    }

    init(modifiers: Set<String> = [], key: String = "") {
        self.modifiers = modifiers
        self.key = key
    }

    init(_ binding: SkhdBinding) {
        self.modifiers = Set(binding.modifiers.map { $0.lowercased() })
        self.key = binding.key
    }
}
