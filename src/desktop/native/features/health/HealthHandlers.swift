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
        register("health.copyFix") { [weak model] (params: HealthFixParams) in
            guard let check = latest?.checks.first(where: { $0.id == params.id }),
                check.status != .passed, let fix = check.command ?? check.fix
            else {
                throw BridgeFailure(.invalidParams, "Check Setup health again to find this fix.")
            }
            guard actions.copy(fix) else {
                model?.log.failure("copy fix", "The clipboard could not be written.")
                throw BridgeFailure(.operationFailed, "The fix could not be copied. Try again.")
            }
            model?.log.note("copy fix", check.title)
            return Null()
        }
        register("health.revealSettings") { [weak model] (_: Empty) in
            actions.reveal()
            model?.log.note("reveal settings", "Opened in Finder")
            return Null()
        }
    }
}
