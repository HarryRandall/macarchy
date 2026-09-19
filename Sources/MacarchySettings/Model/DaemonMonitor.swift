import Foundation
import Observation

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

@MainActor
@Observable
final class DaemonMonitor {
    private(set) var states: [Daemon: DaemonState] = [:]

    private let backend: StackBackend
    private let log: CommandLog

    init(backend: StackBackend, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    var runningCount: Int { states.values.filter(\.isRunning).count }

    func refresh() async {
        for daemon in Daemon.allCases {
            states[daemon] = await backend.state(of: daemon)
        }
    }

    func restart(_ daemon: Daemon) async {
        log.record(await backend.restart(daemon))
        states[daemon] = await backend.state(of: daemon)
    }

    func stop(_ daemon: Daemon) async {
        log.record(await backend.stop(daemon))
        states[daemon] = await backend.state(of: daemon)
    }
}
