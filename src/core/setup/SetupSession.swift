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
        /// Why the run stopped early or left a step out, or nil when every
        /// step ran. The lines still describe what changed before it stopped.
        public var failure: String?
    }

    /// Does not throw, so a run that stops partway still reports the backups,
    /// files and services it had already changed alongside the reason.
    /// Without `applyToDesktop` only the files change: no service is started
    /// and no theme is applied, so a scripted setup can leave the desktop alone.
    public func run(
        existing: Setup.Existing, app: URL?, applyToDesktop: Bool = true
    ) async -> Report {
        var lines: [String] = []
        var commands: [CommandResult] = []
        var failure: String?
        do {
            lines = try await Setup.run(existing: existing, app: app)
        } catch {
            if let interrupted = error as? Setup.Interrupted { lines = interrupted.lines }
            return Report(
                lines: lines, commands: [],
                failure: error is Setup.Refused
                    ? error.localizedDescription
                    : "Setup did not finish; some files may already have changed. "
                        + error.localizedDescription)
        }
        if applyToDesktop {
            commands = await Setup.startServices(integrations: integrations)
            // Every file step has run by now, so only the theme is left out.
            do {
                if let theme = try SettingsStore().read().currentTheme {
                    commands.append(await applyTheme(theme))
                }
            } catch {
                failure =
                    "Setup finished, but the theme was not applied because the settings "
                    + "could not be read. " + error.localizedDescription
            }
        }
        lines += commands.map {
            $0.ok ? $0.summary : "Some changes applied. \($0.command): \($0.summary)"
        }
        return Report(lines: lines, commands: commands, failure: failure)
    }

    public func restoreOriginals() async throws -> Report {
        do {
            let lines = try await Setup.uninstall(integrations: integrations)
            let commands = await Setup.returnServices(integrations: integrations)
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
