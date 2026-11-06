import Foundation

/// The LaunchAgents that keep the daemons running, owned by Macarchy.
///
/// Each one starts its daemon with the config in `Paths.configDirectory`, so
/// the daemons never read the places they look by default. yabai and
/// SketchyBar run that file through `sh -c` unquoted, which a path in
/// Application Support defeats, so they start from a bundled launcher. The agents yabai,
/// skhd and Homebrew install for themselves are stopped once Macarchy's runs,
/// and backed up so uninstall can bring them back.
///
/// borders is started through bordersrc rather than directly. Homebrew's agent
/// started Homebrew's binary, and bordersrc's own `borders` call then only
/// forwarded settings to it, so a custom build in `Paths.binDirectory` never
/// drew anything. bordersrc execs the binary `Paths.borders` chooses instead.
public enum DaemonAgents {
    static let prefix = "io.github.harryrandall.macarchy."

    public static func label(_ daemon: Daemon) -> String { prefix + daemon.rawValue }

    static var agents: URL { Paths.home.appending(path: "Library/LaunchAgents") }

    public static func plist(_ daemon: Daemon) -> URL {
        agents.appending(path: "\(label(daemon)).plist")
    }

    /// Other installers' agents for the daemon, which Macarchy's replaces.
    static func replaced(_ daemon: Daemon) -> [URL] {
        daemon.knownLabels.filter { $0 != label(daemon) }
            .map { agents.appending(path: "\($0).plist") }
    }

    static var domain: String { "gui/\(getuid())" }

    static func arguments(_ daemon: Daemon) -> [String] {
        switch daemon {
        case .yabai: [Paths.yabai, "-c", BundledStartLauncher.url(.yabai).path]
        case .skhd: [Paths.skhd, "-c", Setup.skhdrc.path]
        case .sketchybar:
            [Paths.sketchybar, "--config", BundledStartLauncher.url(.sketchybar).path]
        case .borders: [StartupConfiguration.bordersrc.url.path]
        }
    }

    /// What the daemons' commands can run by name. launchd starts jobs with
    /// almost no PATH, so this names the bundled CLI, Macarchy's own bin, the
    /// folder yabai was found in and both Homebrew prefixes. skhd passes it to
    /// every shortcut, so the shortcuts file can say `yabai` and `macarchy`.
    static var path: String {
        let folders = [
            Paths.appLink.appending(path: "Contents/MacOS").path, Paths.binDirectory.path,
            URL(fileURLWithPath: Paths.yabai).deletingLastPathComponent().path,
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ]
        var seen = Set<String>()
        return folders.filter { seen.insert($0).inserted }.joined(separator: ":")
    }

    /// The agent's contents.
    static func agent(_ daemon: Daemon) throws -> Data {
        let log = Paths.stateDirectory.appending(path: "\(daemon.rawValue).log").path
        let dictionary: [String: Any] = [
            "Label": label(daemon),
            "ProgramArguments": arguments(daemon),
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "EnvironmentVariables": ["PATH": path],
            "StandardOutPath": log,
            "StandardErrorPath": log
        ]
        return try PropertyListSerialization.data(
            fromPropertyList: dictionary, format: .xml, options: 0)
    }

    /// Writes Macarchy's agent and backs up the agents it replaces, so
    /// uninstall returns the daemon to its installer. Does not start
    /// anything. Each backup and write appends a line as it happens, so a
    /// failure partway still reports what changed.
    static func install(_ daemon: Daemon, backups: Backups, report: inout [String]) throws {
        let fm = FileManager.default
        let plist = plist(daemon)
        try fm.createDirectory(at: agents, withIntermediateDirectories: true)
        try fm.createDirectory(at: Paths.stateDirectory, withIntermediateDirectories: true)
        for url in try backups.save([plist] + replaced(daemon)) {
            report.append("Backed up \(Paths.display(url))")
        }
        let data = try agent(daemon)
        if (try? Data(contentsOf: plist)) != data {
            try data.write(to: plist, options: .atomic)
            report.append("Wrote \(Paths.display(plist))")
        }
        // The agent written now replaces any copy a failed start set aside.
        try? fm.removeItem(at: asidePlist(daemon))
    }

    /// Where a failed start keeps Macarchy's agent while the installer's runs
    /// the daemon instead, so only one of them starts it at login.
    static func asidePlist(_ daemon: Daemon) -> URL {
        Paths.stateDirectory.appending(path: "agents/\(label(daemon)).plist")
    }

    /// Whether setup gave the daemon an agent, even one a failed start set aside.
    public static func isInstalled(_ daemon: Daemon) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: plist(daemon).path)
            || fm.fileExists(atPath: asidePlist(daemon).path)
    }

    /// Whether a failed start set Macarchy's agent aside for the installer's.
    public static func isSetAside(_ daemon: Daemon) -> Bool {
        let fm = FileManager.default
        return !fm.fileExists(atPath: plist(daemon).path)
            && fm.fileExists(atPath: asidePlist(daemon).path)
    }

    /// Stops the installer's job, loads Macarchy's, and only once Macarchy's
    /// is running removes the installer's agent so it cannot return at login.
    ///
    /// A loaded job keeps the definition launchd read, and `kickstart` only
    /// restarts that, so a job whose agent changed on disk since (an earlier
    /// Macarchy agent under the same label, or a new PATH) is unloaded and
    /// loaded again first.
    ///
    /// If Macarchy's job fails, see `rollBack`.
    /// An isolated run reaches only a fake launchctl on its search path, or
    /// none, so these calls never touch the real login session.
    public static func start(_ daemon: Daemon, integrations: Integrations) async -> CommandResult {
        let fm = FileManager.default
        let ours = label(daemon)
        if isSetAside(daemon) {
            do { try restoreSetAside(daemon) } catch {
                return CommandResult(
                    command: "\(daemon.rawValue) service", status: 1,
                    stderr: "Macarchy's agent for \(daemon.displayName) could not be put back: "
                        + error.localizedDescription)
            }
        }
        var installers = Installers(
            agents: replaced(daemon).filter { fm.fileExists(atPath: $0.path) })
        for agent in installers.agents {
            let job = agent.deletingPathExtension().lastPathComponent
            let before = await integrations.execute(Paths.launchctl, ["print", target(job)])
            if before.ok, before.skipped.isEmpty, LoadedJob(before.stdout).running {
                installers.running.append(agent)
            }
            await unload(job, integrations: integrations)
        }
        let loaded = await integrations.execute(Paths.launchctl, ["print", target(ours)])
        var needsLoading = !loaded.ok
        if loaded.ok, loaded.skipped.isEmpty,
            LoadedJob(loaded.stdout).definition != definition(at: plist(daemon))
        {
            await unload(ours, integrations: integrations)
            needsLoading = true
        }
        if needsLoading {
            let bootstrap = await integrations.execute(
                Paths.launchctl, ["bootstrap", domain, plist(daemon).path])
            if !bootstrap.ok {
                return await rollBack(
                    daemon, failure: bootstrap, loaded: false, installers: installers,
                    integrations: integrations)
            }
        }
        let started = await integrations.restart(daemon)
        guard started.ok else {
            return await rollBack(
                daemon, failure: started, loaded: true, installers: installers,
                integrations: integrations)
        }
        if let failure = remove(installers.agents, daemon: daemon) { return failure }
        return started
    }

    /// The installers' agents found for a daemon, and those whose job was
    /// running before Macarchy's start stopped it.
    private struct Installers {
        var agents: [URL]
        var running: [URL] = []
    }

    /// After Macarchy's job failed to start, leaves exactly one agent in
    /// charge of the daemon, now and at login, and says which.
    ///
    /// If an installer's job was running before the start, it worked, so it
    /// is loaded again and Macarchy's agent is set aside until the next
    /// start or setup. Otherwise there is nothing better to go back to:
    /// Macarchy's job stays loaded, so launchd keeps trying it (skhd comes up
    /// once Secure Input is off), and the installers' agents, which were not
    /// running and are backed up, are removed as a successful start would.
    private static func rollBack(
        _ daemon: Daemon, failure: CommandResult, loaded: Bool, installers: Installers,
        integrations: Integrations
    ) async -> CommandResult {
        let note: String
        let working = installers.running
        if working.isEmpty {
            if let removal = remove(installers.agents, daemon: daemon) {
                note = removal.stderr
            } else {
                note =
                    loaded
                    ? "Macarchy's agent stays loaded, so launchd keeps trying to start it."
                    : "Macarchy's agent stays in place and is tried again at login."
            }
        } else {
            if loaded { await unload(label(daemon), integrations: integrations) }
            await load(working, integrations: integrations)
            let names = working.map { $0.deletingPathExtension().lastPathComponent }
                .joined(separator: ", ")
            do {
                try setAside(daemon)
                note =
                    "\(daemon.displayName) runs from \(names) again. Macarchy's agent was set "
                    + "aside so only that one starts at login; use Restart all in Macarchy "
                    + "to try it again."
            } catch {
                note =
                    "\(daemon.displayName) runs from \(names) again, but Macarchy's agent could "
                    + "not be set aside and may start a second copy at login: "
                    + error.localizedDescription
            }
        }
        let stderr = failure.stderr.isEmpty ? note : "\(failure.stderr)\n\(note)"
        return CommandResult(
            command: failure.command, status: failure.status,
            stdout: failure.stdout, stderr: stderr, skipped: failure.skipped)
    }

    /// Removes the installers' agents once Macarchy's is in charge, so they
    /// cannot start a second copy at login. Returns a failure to report, or nil.
    private static func remove(_ others: [URL], daemon: Daemon) -> CommandResult? {
        for agent in others {
            do { try FileManager.default.removeItem(at: agent) } catch {
                return CommandResult(
                    command: "\(daemon.rawValue) service", status: 1,
                    stderr: "\(daemon.displayName) runs from Macarchy, but its old agent could "
                        + "not be removed and may start a second copy at login: "
                        + error.localizedDescription)
            }
        }
        return nil
    }

    private static func setAside(_ daemon: Daemon) throws {
        let fm = FileManager.default
        let destination = asidePlist(daemon)
        try fm.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: destination)
        try fm.moveItem(at: plist(daemon), to: destination)
    }

    /// Writes the agent fresh rather than moving the old copy back, since
    /// the paths it names may have changed while it was aside.
    private static func restoreSetAside(_ daemon: Daemon) throws {
        try agent(daemon).write(to: plist(daemon), options: .atomic)
        try FileManager.default.removeItem(at: asidePlist(daemon))
    }

    private static func target(_ job: String) -> String { "\(domain)/\(job)" }

    /// Boots a job out and waits for it to go: bootout returns before the
    /// process has, and two daemons would fight over the same windows, or a
    /// bootstrap straight after would find the old job still there.
    private static func unload(_ job: String, integrations: Integrations) async {
        _ = await integrations.execute(Paths.launchctl, ["bootout", target(job)])
        for _ in 0..<20 {
            let state = await integrations.execute(Paths.launchctl, ["print", target(job)])
            // An isolated run refuses launchctl without failing; there is
            // nothing to wait for then.
            if !state.ok || !state.skipped.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// The parts of an agent on disk that `launchctl print` reports back, or
    /// nil when it cannot be read, so it never matches a loaded job.
    static func definition(at url: URL) -> LoadedJob.Definition? {
        guard let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any],
            let arguments = plist["ProgramArguments"] as? [String]
        else { return nil }
        let environment = plist["EnvironmentVariables"] as? [String: String]
        return LoadedJob.Definition(
            arguments: arguments, path: environment?["PATH"],
            standardOut: plist["StandardOutPath"] as? String,
            standardError: plist["StandardErrorPath"] as? String)
    }

    private static func load(_ agents: [URL], integrations: Integrations) async {
        for agent in agents {
            _ = await integrations.execute(Paths.launchctl, ["bootstrap", domain, agent.path])
        }
    }

    /// Before uninstall restores files: unload Macarchy's jobs.
    static func stopAll(integrations: Integrations) async {
        for daemon in Daemon.allCases {
            _ = await integrations.execute(
                Paths.launchctl, ["bootout", "\(domain)/\(label(daemon))"])
        }
    }

    /// After a failed uninstall: start each daemon from whichever agent it
    /// has now, Macarchy's if it is still in place, otherwise the
    /// installer's if it came back, rather than leaving it stopped.
    static func resume(integrations: Integrations) async {
        let fm = FileManager.default
        for daemon in Daemon.allCases {
            let ours = plist(daemon)
            let agents =
                fm.fileExists(atPath: ours.path)
                ? [ours] : replaced(daemon).filter { fm.fileExists(atPath: $0.path) }
            await load(agents, integrations: integrations)
        }
    }

    /// After uninstall restored files: load the installers' agents that came
    /// back, and forget any agent of Macarchy's a failed start set aside.
    static func restoreReplaced(integrations: Integrations) async {
        let fm = FileManager.default
        for daemon in Daemon.allCases { try? fm.removeItem(at: asidePlist(daemon)) }
        await load(
            Daemon.allCases.flatMap(replaced).filter { fm.fileExists(atPath: $0.path) },
            integrations: integrations)
    }
}
