import AppKit
import Foundation
import Macarchy
import Observation

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

    private var services: DesktopServices {
        DesktopServices(
            integrations: backend, deactivate: { NSApp.deactivate() },
            activate: { NSApp.activate() })
    }

    @discardableResult
    func restart(_ daemon: Daemon) async -> CommandResult {
        let result = await services.restart(daemon)
        log.record(result)
        states[daemon] = await backend.state(of: daemon)
        return result
    }

    @discardableResult
    func stop(_ daemon: Daemon) async -> CommandResult {
        let result = await services.stop(daemon)
        log.record(result)
        states[daemon] = await backend.state(of: daemon)
        return result
    }
}
