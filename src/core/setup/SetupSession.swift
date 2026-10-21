import Foundation

/// The ordered setup transaction, with desktop application injectable for tests.
public struct SetupSession: Sendable {
    public let integrations: Integrations
    private let applyTheme: @Sendable (String) async -> CommandResult

    public init(
        integrations: Integrations = Integrations(),
        applyTheme: (@Sendable (String) async -> CommandResult)? = nil
    ) {
        self.integrations = integrations
        self.applyTheme =
            applyTheme ?? { await ThemeApplication(integrations: integrations).apply(name: $0) }
    }

    public struct Report: Sendable {
        public var lines: [String]
        public var commands: [CommandResult]
        /// Why the run stopped early, or nil when every step ran. The lines
        /// still describe what changed before it stopped.
        public var failure: String?
    }

    /// Does not throw, so a run that stops partway still reports the backups,
    /// files and services it had already changed alongside the reason.
    public func run(existing: Setup.Existing, app: URL?) async -> Report {
        var lines: [String] = []
        var commands: [CommandResult] = []
        var failure: String?
        do {
            lines = try await Setup.run(existing: existing, app: app)
            commands = await Setup.startServices(integrations: integrations)
            if let theme = try SettingsStore().read().currentTheme {
                commands.append(await applyTheme(theme))
            }
        } catch {
            if let interrupted = error as? Setup.Interrupted { lines = interrupted.lines }
            failure =
                "Setup did not finish; some files may already have changed. "
                + error.localizedDescription
        }
        lines += commands.map {
            $0.ok ? $0.summary : "Some changes applied. \($0.command): \($0.summary)"
        }
        return Report(lines: lines, commands: commands, failure: failure)
    }

    public func restoreOriginals() async throws -> Report {
        do {
            let lines = try await Setup.uninstall(integrations: integrations)
            let commands = await Setup.startServices(integrations: integrations)
            return Report(
                lines: lines
                    + commands.filter { !$0.ok }.map { "Files restored, but \($0.summary)" },
                commands: commands, failure: nil)
        } catch {
            throw ConfigurationError(
                "Restore did not finish; some files or services may already have changed. "
                    + error.localizedDescription)
        }
    }
}
