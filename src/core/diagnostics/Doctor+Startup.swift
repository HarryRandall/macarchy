import Foundation

/// Checks that each daemon can run, and did run, the startup file its agent
/// names. A daemon that starts without it looks healthy everywhere else.
extension Doctor {
    /// The daemons whose startup file runs `macarchy startup`, which records
    /// the run (`Startup.recordRun`).
    static let recordedDaemons: [Daemon] = [.yabai, .sketchybar, .borders]

    /// How long a daemon may run before its startup file has to have run:
    /// yabai and SketchyBar run it only once they are up.
    static let startupGrace = 15

    /// The file Macarchy's agent tells the daemon to run, for the daemons
    /// that take one on the command line.
    static func startFile(_ daemon: Daemon) -> URL? {
        guard let arguments = DaemonAgents.definition(at: DaemonAgents.plist(daemon))?.arguments
        else { return nil }
        let flag: String
        switch daemon {
        case .yabai: flag = "-c"
        case .sketchybar: flag = "--config"
        case .borders, .skhd: return nil
        }
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    /// What stops the daemon running the file its agent names, or nil.
    /// yabai and SketchyBar run it as `sh -c <path>` unquoted, so a path
    /// with a space, as agents written before the launchers had, never runs.
    static func startFileProblem(_ daemon: Daemon) -> String? {
        guard let file = startFile(daemon) else { return nil }
        if file.path.rangeOfCharacter(from: .whitespaces) != nil {
            return "Macarchy's agent starts \(Paths.display(file)), which \(daemon.displayName) "
                + "runs through sh, splitting the path at the space, so it never runs"
        }
        if !FileManager.default.fileExists(atPath: file.path) {
            return "Macarchy's agent starts \(Paths.display(file)), which is missing"
        }
        return nil
    }

    /// The service row for a running daemon: whether the copy running now
    /// ran its startup file. Nil when that cannot be told, as for a daemon
    /// another installer's agent runs (`ours` false), which never runs
    /// Macarchy's file.
    static func startupCheck(
        _ daemon: Daemon, ours: Bool, pid: Int, recorded: Int?, secondsRunning: Int?
    ) -> HealthCheck? {
        guard ours, recordedDaemons.contains(daemon) else { return nil }
        if recorded == pid {
            return HealthCheck(.services, daemon.displayName, .passed, "Running")
        }
        if let seconds = secondsRunning, seconds < startupGrace {
            return HealthCheck(.services, daemon.displayName, .unknown, "Starting")
        }
        let missing =
            switch daemon {
            case .yabai: "layout, rules and window signals are missing"
            case .sketchybar: "the bar is not set up"
            default: "borders do not follow the theme"
            }
        let log = Paths.stateDirectory.appending(path: "\(daemon.rawValue).log")
        return HealthCheck(
            .services, daemon.displayName, .failed,
            "Running, but it has not run its startup file since it started, so \(missing)",
            fix: "Run setup again, then restart \(daemon.displayName) from Advanced. "
                + "\(Paths.display(log)) says what went wrong",
            command: setupCommand)
    }

    /// How long the process has run, from `ps`, or nil if it cannot tell.
    static func secondsRunning(_ pid: Int, integrations: Integrations) async -> Int? {
        let result = await integrations.execute(Paths.ps, ["-p", "\(pid)", "-o", "etime="])
        guard result.ok, result.skipped.isEmpty else { return nil }
        return elapsedSeconds(result.stdout)
    }

    /// `ps` elapsed time, `[[dd-]hh:]mm:ss`, in seconds.
    static func elapsedSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayParts = trimmed.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(dayParts.count), let clock = dayParts.last else { return nil }
        let days = dayParts.count == 2 ? Int(dayParts[0]) : 0
        let fields = clock.split(separator: ":", omittingEmptySubsequences: false).map {
            Int($0)
        }
        guard let days, (2...3).contains(fields.count), !fields.contains(nil) else { return nil }
        let seconds = fields.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
        return days * 86_400 + seconds
    }
}
