import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class SnapshotBrowser {
    private(set) var snapshots: [SnapshotStore.Snapshot] = []
    private let store = SnapshotStore()
    /// Page reads call this, and an unchanged assignment would still notify `StateBroadcast`.
    func refresh() {
        let next = store.list()
        if snapshots != next { snapshots = next }
    }

    func reason(for snapshot: SnapshotStore.Snapshot) -> String { store.reason(for: snapshot) }
}
