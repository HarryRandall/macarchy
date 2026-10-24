import Foundation

/// The LaunchAgents that keep the daemons running, owned by Macarchy.
///
/// Each one starts its daemon with the config in `Paths.configDirectory`, so
/// the daemons never read the places they look by default. The agents yabai,
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
        case .yabai: [Paths.yabai, "-c", StartupConfiguration.yabairc.url.path]
        case .skhd: [Paths.skhd, "-c", Setup.skhdrc.path]
        case .sketchybar: [Paths.sketchybar, "--config", StartupConfiguration.sketchybarrc.url.path]
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
    }

    /// Stops the installer's job, loads Macarchy's, and only once Macarchy's
    /// is running removes the installer's agent so it cannot return at login.
    /// If Macarchy's job fails, the installer's is loaded again rather than
    /// leaving the daemon stopped.
    /// An isolated run reaches only a fake launchctl on its search path, or
    /// none, so these calls never touch the real login session.
    public static func start(_ daemon: Daemon, integrations: Integrations) async -> CommandResult {
        let fm = FileManager.default
        let others = replaced(daemon).filter { fm.fileExists(atPath: $0.path) }
        for agent in others {
            let job = agent.deletingPathExtension().lastPathComponent
            _ = await integrations.execute(Paths.launchctl, ["bootout", "\(domain)/\(job)"])
            // bootout returns before the process has gone; two daemons would
            // fight over the same windows.
            for _ in 0..<20 {
                let state = await integrations.execute(
                    Paths.launchctl, ["print", "\(domain)/\(job)"])
                if !state.ok { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let ours = label(daemon)
        let loaded = await integrations.execute(Paths.launchctl, ["print", "\(domain)/\(ours)"])
        if !loaded.ok {
            let bootstrap = await integrations.execute(
                Paths.launchctl, ["bootstrap", domain, plist(daemon).path])
            if !bootstrap.ok {
                await load(others, integrations: integrations)
                return bootstrap
            }
        }
        let started = await integrations.restart(daemon)
        guard started.ok else {
            _ = await integrations.execute(Paths.launchctl, ["bootout", "\(domain)/\(ours)"])
            await load(others, integrations: integrations)
            return started
        }
        for agent in others {
            do { try fm.removeItem(at: agent) } catch {
                return CommandResult(
                    command: "\(daemon.rawValue) service", status: 1,
                    stderr: "\(daemon.displayName) runs from Macarchy, but its old agent could "
                        + "not be removed and may start a second copy at login: "
                        + error.localizedDescription)
            }
        }
        return started
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

    /// After uninstall restored files: load the installers' agents that came back.
    static func restoreReplaced(integrations: Integrations) async {
        let fm = FileManager.default
        await load(
            Daemon.allCases.flatMap(replaced).filter { fm.fileExists(atPath: $0.path) },
            integrations: integrations)
    }
}
