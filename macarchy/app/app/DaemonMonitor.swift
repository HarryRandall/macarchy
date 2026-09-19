import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class DaemonMonitor {
    private(set) var states: [Daemon: DaemonState] = [:]

    private let backend: Integrations
    private let log: CommandLog

    init(backend: Integrations, log: CommandLog) {
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
