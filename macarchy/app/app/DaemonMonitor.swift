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

    func restart(_ daemon: Daemon) async {
        let yielded = daemon == .skhd ? await yieldSecureInput() : false
        log.record(await backend.restart(daemon))
        if yielded { NSApp.activate() }
        states[daemon] = await backend.state(of: daemon)
    }

    func stop(_ daemon: Daemon) async {
        log.record(await backend.stop(daemon))
        states[daemon] = await backend.state(of: daemon)
    }

    /// Secure Keyboard Entry is session-wide and the hotkey daemon refuses to
    /// start under it, so a restart clicked while this app holds it can only
    /// ever fail — and this app holds it precisely when its own button is being
    /// clicked. Giving up active status is the whole fix; the window comes back
    /// the moment the restart is done.
    ///
    /// Returns whether focus was actually surrendered, so it is only taken back
    /// when it was given away.
    private func yieldSecureInput() async -> Bool {
        guard let holder = await backend.secureInput(), holder.isThisProcess else { return false }
        NSApp.deactivate()
        // macOS drops secure input a moment after the app stops being active,
        // and waiting for it beats racing it. If it never clears, the restart
        // still runs and reports the holder rather than failing silently.
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(80))
            if await backend.secureInput() == nil { break }
        }
        return true
    }
}
