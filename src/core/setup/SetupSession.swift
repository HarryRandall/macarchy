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
    }

    public func run(existing: Setup.Existing, app: URL?) async throws -> Report {
        do {
            var lines = try await Setup.run(existing: existing, app: app)
            var commands = await Setup.startServices(integrations: integrations)
            if let theme = try SettingsStore().read().currentTheme {
                commands.append(await applyTheme(theme))
            }
            lines += commands.map {
                $0.ok ? $0.summary : "Some changes applied. \($0.command): \($0.summary)"
            }
            return Report(lines: lines, commands: commands)
        } catch {
            throw ConfigurationError(
                "Setup did not finish; some files may already have changed. "
                    + error.localizedDescription)
        }
    }

    public func restoreOriginals() async throws -> Report {
        do {
            let lines = try await Setup.uninstall(integrations: integrations)
            let commands = await Setup.startServices(integrations: integrations)
            return Report(
                lines: lines
                    + commands.filter { !$0.ok }.map { "Files restored, but \($0.summary)" },
                commands: commands)
        } catch {
            throw ConfigurationError(
                "Restore did not finish; some files or services may already have changed. "
                    + error.localizedDescription)
        }
    }
}
