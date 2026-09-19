import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class SnapshotBrowser {
    private(set) var snapshots: [SnapshotStore.Snapshot] = []
    private let store = SnapshotStore()
    private let log: CommandLog

    init(log: CommandLog) { self.log = log }

    func refresh() { snapshots = store.list() }

    func reason(for snapshot: SnapshotStore.Snapshot) -> String { store.reason(for: snapshot) }

    func restore(_ snapshot: SnapshotStore.Snapshot) async {
        do {
            try store.restore(snapshot)
            try await DesktopConfiguration.apply()
            log.note(
                "restored \(snapshot.id)",
                "Saved settings restored and applied")
        } catch {
            log.note("restore failed", error.localizedDescription)
        }
        refresh()
    }
}
