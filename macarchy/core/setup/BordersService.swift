import Foundation

/// The LaunchAgent that keeps borders running, owned by Macarchy.
///
/// Homebrew's agent starts Homebrew's binary. borders then runs bordersrc,
/// whose own `borders` call only forwards settings to the instance already
/// running, so a custom build in `~/.config/macarchy/bin` never drew
/// anything and two processes appeared. Macarchy's agent runs bordersrc
/// itself, which execs the binary `Paths.borders` chooses, so exactly one
/// daemon runs and it is the right one.
public enum BordersService {
    public static let label = "io.github.harryrandall.macarchy.borders"

    static var agents: URL { Paths.home.appending(path: "Library/LaunchAgents") }
    static var plist: URL { agents.appending(path: "\(label).plist") }
    static var homebrewPlists: [URL] {
        ["sh.brew.borders", "homebrew.mxcl.borders"].map { agents.appending(path: "\($0).plist") }
    }

    /// launchctl changes reach the real login session even when tests point
    /// `MACARCHY_HOME` elsewhere, so they only run against the real home.
    static var isolated: Bool { ProcessInfo.processInfo.environment["MACARCHY_HOME"] != nil }

    static var domain: String { "gui/\(getuid())" }

    /// The agent's contents. PATH covers both Homebrew prefixes, since
    /// launchd starts jobs with almost none.
    static func agent() throws -> Data {
        let log = Paths.appRoot.appending(path: "state/borders.log").path
        let dictionary: [String: Any] = [
            "Label": label,
            "ProgramArguments": [StartupConfiguration.bordersrc.url.path],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "EnvironmentVariables": [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ],
            "StandardOutPath": log,
            "StandardErrorPath": log
        ]
        return try PropertyListSerialization.data(
            fromPropertyList: dictionary, format: .xml, options: 0)
    }

    /// Writes Macarchy's agent and moves Homebrew's aside, backing both up
    /// so uninstall returns borders to Homebrew. Does not start anything.
    static func install(backups: Backups) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: agents, withIntermediateDirectories: true)
        try fm.createDirectory(
            at: Paths.appRoot.appending(path: "state"), withIntermediateDirectories: true)
        try backups.save([plist] + homebrewPlists)
        let data = try agent()
        if (try? Data(contentsOf: plist)) != data { try data.write(to: plist, options: .atomic) }
    }

    /// Stops Homebrew's job, loads Macarchy's, and only once Macarchy's is
    /// running removes Homebrew's agent so it cannot return at login. If
    /// Macarchy's job fails, Homebrew's is loaded again rather than leaving
    /// no borders at all.
    public static func start(integrations: Integrations) async -> CommandResult {
        guard !isolated else { return CommandResult(command: "borders service", status: 0) }
        let fm = FileManager.default
        let homebrew = homebrewPlists.filter { fm.fileExists(atPath: $0.path) }
        for agent in homebrew {
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
        let loaded = await integrations.execute(
            Paths.launchctl, ["print", "\(domain)/\(label)"])
        if !loaded.ok {
            let bootstrap = await integrations.execute(
                Paths.launchctl, ["bootstrap", domain, plist.path])
            if !bootstrap.ok {
                await reloadHomebrew(homebrew, integrations: integrations)
                return bootstrap
            }
        }
        let started = await integrations.restart(.borders)
        guard started.ok else {
            _ = await integrations.execute(Paths.launchctl, ["bootout", "\(domain)/\(label)"])
            await reloadHomebrew(homebrew, integrations: integrations)
            return started
        }
        for agent in homebrew {
            do { try fm.removeItem(at: agent) } catch {
                return CommandResult(
                    command: "borders service", status: 1,
                    stderr: "Borders runs from Macarchy, but Homebrew's agent could not be "
                        + "removed and may start a second copy at login: "
                        + error.localizedDescription)
            }
        }
        return started
    }

    private static func reloadHomebrew(_ agents: [URL], integrations: Integrations) async {
        for agent in agents {
            _ = await integrations.execute(Paths.launchctl, ["bootstrap", domain, agent.path])
        }
    }

    /// Before uninstall restores files: unload Macarchy's job.
    static func stop(integrations: Integrations) async {
        guard !isolated else { return }
        _ = await integrations.execute(Paths.launchctl, ["bootout", "\(domain)/\(label)"])
    }

    /// After uninstall restored files: load Homebrew's agent again if it came back.
    static func restoreHomebrew(integrations: Integrations) async {
        guard !isolated else { return }
        for homebrew in homebrewPlists where FileManager.default.fileExists(atPath: homebrew.path) {
            _ = await integrations.execute(Paths.launchctl, ["bootstrap", domain, homebrew.path])
        }
    }
}
