import Foundation
import Macarchy

extension BridgeRouter {
    func registerReport(model: AppModel, actions: DiagnosticActions = .live) {
        let session = ReportSession()
        register("report.prepare") { [weak model] (params: ReportPrepareParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let prepared = await session.prepare(params.description, integrations: model.backend)
            model.log.note("prepare report", "Redacted diagnostic report prepared")
            return prepared
        }
        register("report.copy") { [weak model] (params: ReportCopyParams) in
            let report = try session.report(token: params.token)
            guard actions.copy(report.body) else {
                model?.log.failure("copy report", "The clipboard could not be written.")
                throw BridgeFailure(.operationFailed, "The report could not be copied. Try again.")
            }
            model?.log.note("copy report", "Copied redacted report")
            return Null()
        }
        register("report.openIssue") { [weak model] (params: ReportOpenParams) in
            do {
                let report = try session.report(token: params.token)
                let submission = try report.submission(title: params.title)
                if submission.copyBody, !actions.copy(report.body) {
                    throw ConfigurationError("The report could not be copied. Try again.")
                }
                guard actions.open(submission.url) else {
                    throw ConfigurationError(
                        "The browser could not be opened. Copy the report and try again.")
                }
                model?.log.note("open issue", "Opened GitHub for review")
                return ReportOpened(copied: submission.copyBody)
            } catch {
                model?.log.failure("open issue", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
        register("report.openIssues") { [weak model] (_: Empty) in
            guard actions.open(Diagnostics.repository.appending(path: "issues")) else {
                model?.log.failure("open issues", "The browser could not be opened.")
                throw BridgeFailure(.operationFailed, "The browser could not be opened. Try again.")
            }
            model?.log.note("open issues", "Opened GitHub")
            return Null()
        }
    }
}

/// Keep the collected facts and the exact preview together. No logs or draft
/// text are stored on disk, and a stale preview cannot be submitted.
@MainActor
private final class ReportSession {
    private var collection: Task<DiagnosticSnapshot, Never>?
    private var latest: ReportState?

    func prepare(_ description: String, integrations: Integrations) async -> ReportState {
        let collection =
            collection ?? Task { await DiagnosticSnapshot.read(integrations: integrations) }
        self.collection = collection
        let snapshot = await collection.value
        let state = ReportState(
            body: snapshot.report(description: description), token: UUID().uuidString)
        latest = state
        return state
    }

    func report(token: String) throws -> ProblemReport {
        guard let latest, latest.token == token else {
            throw BridgeFailure(
                .invalidParams, "Wait for the report preview to finish, then try again.")
        }
        return ProblemReport(redactedBody: latest.body)
    }
}
