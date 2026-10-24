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

    /// Every integration is optional, so a tool that is not installed is left
    /// out of the counts and of Restart All rather than shown as stopped.
    /// Replaceable so tests do not depend on what this Mac has installed.
    var isInstalled: @MainActor (Daemon) -> Bool = { Paths.isInstalled($0.executableName) }

    /// Starts one service for Restart All. The live start is the one
    /// `macarchy services` uses; tests replace it so they never read or change
    /// the real LaunchAgents.
    var start: @MainActor (Daemon) async -> CommandResult

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
        let services = DesktopServices(
            integrations: backend, deactivate: { NSApp.deactivate() },
            activate: { NSApp.activate() })
        start = { await services.start($0) }
    }

    var installed: [Daemon] { Daemon.allCases.filter(isInstalled) }

    var runningCount: Int { installed.filter { states[$0]?.isRunning == true }.count }

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

    /// Starts every installed service in turn, as `macarchy services` does:
    /// a registered one restarts and one without a LaunchAgent is registered.
    @discardableResult
    func restartAll() async -> [Restart] {
        var results: [Restart] = []
        for daemon in installed {
            let result = await start(daemon)
            log.record(result)
            await update(daemon)
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
