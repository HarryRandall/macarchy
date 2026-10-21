import Foundation

/// The same bounded facts used by Setup health and problem reports.
public struct DiagnosticSnapshot: Sendable {
    public var checks: [HealthCheck]
    public var environment: Diagnostics.Environment
    public var checkedAt: Date

    public static func read(integrations: Integrations = Integrations()) async -> Self {
        async let checks = Doctor.checks(integrations: integrations)
        async let environment = Diagnostics.environment(integrations: integrations)
        return await Self(checks: checks, environment: environment, checkedAt: .now)
    }

    public func report(description: String) -> String {
        Diagnostics.report(
            title: "", description: description, environment: environment, checks: checks)
    }
}

/// A browser hand-off. Long reports are copied in full for the person to paste.
public struct ProblemReport: Sendable {
    public let body: String

    public init(redactedBody: String) { self.body = redactedBody }

    public func submission(title: String) throws -> (url: URL, copyBody: Bool) {
        let title = Diagnostics.redact(title.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !title.isEmpty else { throw ConfigurationError("Enter a short summary first.") }
        if let url = Diagnostics.issueURL(title: title, body: body) { return (url, false) }
        guard let url = Diagnostics.issueURL(title: title, body: "") else {
            throw ConfigurationError(
                "The summary is too long for a link. Shorten it and try again.")
        }
        return (url, true)
    }
}
