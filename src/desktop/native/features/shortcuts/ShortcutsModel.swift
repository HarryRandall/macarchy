import Macarchy
import Observation

/// The remaining classic Home summary uses the same read as the React page.
@MainActor
@Observable
final class ShortcutsModel {
    private(set) var bindings: [SkhdBinding] = []
    private let log: CommandLog

    init(log: CommandLog) { self.log = log }

    func reload() {
        do {
            bindings = try SkhdShortcuts().read().bindings
        } catch {
            log.failure("read shortcuts", error.localizedDescription)
        }
    }
}
