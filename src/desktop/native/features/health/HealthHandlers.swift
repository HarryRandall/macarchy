import Foundation
import Macarchy

extension BridgeRouter {
    func registerHealth(model: AppModel, actions: DiagnosticActions = .live) {
        var latest: DiagnosticSnapshot?
        register("health.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let snapshot = await DiagnosticSnapshot.read(integrations: model.backend)
            latest = snapshot
            model.log.note("health check", "\(snapshot.checks.count) checks completed")
            return HealthState(snapshot)
        }
        // Both act on the latest reading, so the page names a check, never a
        // command or a path.
        func problem(_ id: String) -> HealthCheck? {
            latest?.checks.first { $0.id == id && $0.status != .passed }
        }
        register("health.copyCommand") { [weak model] (params: HealthCheckParams) in
            guard let check = problem(params.id), let command = check.command else {
                throw BridgeFailure(.invalidParams, "Check Setup health again to find this fix.")
            }
            guard actions.copy(command) else {
                model?.log.failure("copy fix", "The clipboard could not be written.")
                throw BridgeFailure(.operationFailed, "The command could not be copied. Try again.")
            }
            model?.log.note("copy fix", check.title)
            return Null()
        }
        register("health.openFile") { [weak model] (params: HealthCheckParams) in
            guard let check = problem(params.id), let file = check.file else {
                throw BridgeFailure(.invalidParams, "Check Setup health again to find this file.")
            }
            guard actions.open(file) else {
                model?.log.failure("open file", "\(Paths.display(file)) could not be opened.")
                throw BridgeFailure(
                    .operationFailed, "\(file.lastPathComponent) could not be opened.")
            }
            model?.log.note("open file", Paths.display(file))
            return Null()
        }
        register("health.revealSettings") { [weak model] (_: Empty) in
            actions.reveal()
            model?.log.note("reveal settings", "Opened in Finder")
            return Null()
        }
    }
}
