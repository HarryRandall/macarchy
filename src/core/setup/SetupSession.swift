import Foundation

/// The ordered setup transaction, with desktop application and Homebrew
/// injectable for tests.
public struct SetupSession: Sendable {
    public let integrations: Integrations
    /// Installs chosen tools that are missing, and removes the ones Macarchy
    /// installed when restoring asks it to.
    public let installer: ToolInstaller
    private let applyTheme: @Sendable (String) async -> CommandResult
    /// Unregisters the app as a login item on uninstall, returning what to report.
    private let stopOpeningAtLogin: @Sendable () -> String?

    public init(
        integrations: Integrations = Integrations(),
        applyTheme: (@Sendable (String) async -> CommandResult)? = nil,
        stopOpeningAtLogin: @escaping @Sendable () -> String? = { OpenAtLogin.stop() },
        installer: ToolInstaller = ToolInstaller()
    ) {
        self.integrations = integrations
        self.installer = installer
        self.stopOpeningAtLogin = stopOpeningAtLogin
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

    /// Where a run has got to, for a page that shows it.
    public enum Step: Sendable, Equatable {
        /// Installing or removing a tool with Homebrew.
        case homebrew(ToolInstaller.Progress)
        /// Writing the files and starting the services.
        case configuring
    }

    /// Does not throw, so a run that stops partway still reports the backups,
    /// files and services it had already changed alongside the reason.
    /// With `install`, chosen tools that are missing are installed with
    /// Homebrew first; one that fails is reported and setup carries on, so
    /// it is configured once it is installed.
    /// Without `applyToDesktop` only the files change: no service is started
    /// and no theme is applied, so a scripted setup can leave the desktop alone.
    public func run(
        _ choices: Setup.Choices, app: URL?, applyToDesktop: Bool = true, install: Bool = false,
        progress: @escaping @Sendable (Step) -> Void = { _ in }
    ) async -> Report {
        var lines: [String] = []
        var failed: [CommandResult] = []
        if install {
            let missing =
                choices.ordered.filter { !Paths.isInstalled($0.executableName) }.map(\.package)
                + Setup.extras.filter { choices.extras.contains($0.id) && !$0.isInstalled }
            if !missing.isEmpty {
                let installed = await installer.install(missing) {
                    progress(.homebrew($0))
                }
                lines += installed.changed.map { "Installed \($0.name) with Homebrew" }
                failed = installed.failures.map {
                    CommandResult(
                        command: $0.package.command, status: 1,
                        stderr: "\($0.package.name) was not installed: \($0.reason)")
                }
                lines += failed.map(\.stderr)
            }
        }
        progress(.configuring)
        do {
            lines += try await Setup.run(choices, app: app)
        } catch {
            if let interrupted = error as? Setup.Interrupted { lines += interrupted.lines }
            return Report(
                lines: lines, commands: failed,
                failure: error is Setup.Refused
                    ? error.localizedDescription
                    : "Setup did not finish; some files may already have changed. "
                        + error.localizedDescription)
        }
        var commands: [CommandResult] = []
        var failure: String?
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
        return Report(lines: lines, commands: failed + commands, failure: failure)
    }

    /// Puts back the files from before setup, then removes `tools`, which
    /// must be ones Macarchy installed, and hands the rest back to their
    /// installers.
    public func restoreOriginals(
        removing tools: [ToolInstaller.Package] = [],
        progress: @escaping @Sendable (Step) -> Void = { _ in }
    ) async throws -> Report {
        do {
            var lines = try await Setup.uninstall(integrations: integrations)
            var failed: [CommandResult] = []
            if !tools.isEmpty {
                let removed = await installer.uninstall(tools) { progress(.homebrew($0)) }
                lines += removed.changed.map { "Removed \($0.name) with Homebrew" }
                failed = removed.failures.map {
                    CommandResult(
                        command: "brew uninstall \($0.package.formula)", status: 1,
                        stderr: "\($0.package.name) was not removed: \($0.reason)")
                }
                lines += failed.map { "Files restored, but \($0.stderr)" }
            }
            let commands = await Setup.returnServices(integrations: integrations)
            return Report(
                lines: lines
                    + commands.filter { !$0.ok }.map { "Files restored, but \($0.summary)" }
                    + [stopOpeningAtLogin()].compactMap { $0 },
                commands: failed + commands, failure: nil)
        } catch {
            throw ConfigurationError(
                "Restore did not finish; some files or services may already have changed. "
                    + error.localizedDescription)
        }
    }
}
