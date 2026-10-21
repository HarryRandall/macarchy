import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class SnapshotBrowser {
    private(set) var snapshots: [SnapshotStore.Snapshot] = []
    private let store = SnapshotStore()
    func refresh() { snapshots = store.list() }

    func reason(for snapshot: SnapshotStore.Snapshot) -> String { store.reason(for: snapshot) }
}
