import Foundation
import Observation
import Desktop

@MainActor
@Observable
final class SnapshotBrowser {
    private(set) var snapshots: [SnapshotStore.Snapshot] = []
    private let store = SnapshotStore()
    private let log: CommandLog

    init(log: CommandLog) { self.log = log }

    func refresh() { snapshots = store.list() }

    func reason(for snapshot: SnapshotStore.Snapshot) -> String { store.reason(for: snapshot) }

    func restore(_ snapshot: SnapshotStore.Snapshot) {
        do {
            try store.restore(snapshot)
            log.note("restored \(snapshot.id)", "\(snapshot.files.count) files")
        } catch {
            log.note("restore failed", error.localizedDescription)
        }
        refresh()
    }
}
