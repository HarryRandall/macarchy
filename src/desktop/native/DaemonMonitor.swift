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

    /// Page reads call this, and an unchanged assignment would still notify `StateBroadcast`.
    func refresh() async {
        for daemon in Daemon.allCases { await update(daemon) }
    }

    private func update(_ daemon: Daemon) async {
        let state = await backend.state(of: daemon)
        if states[daemon] != state { states[daemon] = state }
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
        await update(daemon)
        return result
    }

    typealias Restart = (daemon: Daemon, result: CommandResult)

    /// Restarts every service in turn.
    @discardableResult
    func restartAll() async -> [Restart] {
        var results: [Restart] = []
        for daemon in Daemon.allCases {
            let result = await restart(daemon)
            results.append((daemon, result))
        }
        return results
    }

    /// One sentence for the page, naming any service that did not come back.
    static func outcome(of results: [Restart]) -> String {
        let failed = results.filter { !$0.result.ok }.map(\.daemon.displayName)
        let total = results.count
        if failed.isEmpty { return "Restarted all \(total) services." }
        if failed.count == total { return "None of the \(total) services restarted." }
        var names = failed.dropLast().joined(separator: ", ")
        names += (names.isEmpty ? "" : " and ") + (failed.last ?? "")
        return "Restarted \(total - failed.count) of \(total) services; \(names) did not restart."
    }

    @discardableResult
    func stop(_ daemon: Daemon) async -> CommandResult {
        let result = await services.stop(daemon)
        log.record(result)
        await update(daemon)
        return result
    }
}
