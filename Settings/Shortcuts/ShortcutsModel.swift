import Foundation
import Observation
import Desktop

/// Read-only view of skhd's bindings.
///
/// Editing lands later behind a macarchy:keep block; parsing first because the
/// parser is the reusable half — generating skhdrc has to round-trip the same
/// model, so it lives beside the daemon in Desktop rather than here.
@MainActor
@Observable
final class ShortcutsModel {
    private(set) var bindings: [SkhdBinding] = []
    var search = ""

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

    /// Sections in the order they appear, so the file's own grouping survives.
    var sections: [String] {
        var seen = Set<String>()
        return filtered.compactMap(\.section).filter { seen.insert($0).inserted }
    }

    func bindings(in section: String) -> [SkhdBinding] {
        filtered.filter { $0.section == section }
    }

    var ungrouped: [SkhdBinding] { filtered.filter { $0.section == nil } }

    private var filtered: [SkhdBinding] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return bindings }
        return bindings.filter {
            $0.command.lowercased().contains(query)
                || $0.keyCaps.joined(separator: " ").lowercased().contains(query)
                || ($0.section?.lowercased().contains(query) ?? false)
                || $0.key.lowercased().contains(query)
        }
    }
}
