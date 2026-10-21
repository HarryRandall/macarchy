import Foundation

/// Subset of `sketchybar --query bar` that the Menu Bar pane cares about.
public struct BarState: Codable, Sendable {
    public var height: Int?
    public var position: String?
    public var blurRadius: Int?
    public var sticky: String?
    public var color: String?
    public var items: [String]?
    public var paddingLeft: Int?
    public var paddingRight: Int?
    public var cornerRadius: Int?
    public var yOffset: Int?

    public enum CodingKeys: String, CodingKey {
        case height, position, sticky, color, items
        case blurRadius = "blur_radius"
        case paddingLeft = "padding_left"
        case paddingRight = "padding_right"
        case cornerRadius = "corner_radius"
        case yOffset = "y_offset"
    }
}

public struct Integrations: Sendable {
    public typealias Execute = @Sendable (String, [String]) async -> CommandResult
    public let execute: Execute
    public init(execute: @escaping Execute = { await CommandRunner.run($0, $1) }) {
        self.execute = execute
    }

    public func yabaiRead(_ key: String) async -> CommandResult {
        await execute(Paths.yabai, ["-m", "config", key])
    }

    public func yabaiWrite(_ key: String, value: String) async -> CommandResult {
        await execute(Paths.yabai, ["-m", "config", key, value])
    }

    public func borders(_ arguments: [String]) async -> CommandResult {
        await execute(Paths.borders, arguments)
    }

    public func barState() async -> (CommandResult, BarState?) {
        let result = await execute(Paths.sketchybar, ["--query", "bar"])
        guard result.ok, let data = result.stdout.data(using: .utf8) else { return (result, nil) }
        return (result, try? JSONDecoder().decode(BarState.self, from: data))
    }

    public func sketchybar(_ arguments: [String]) async -> CommandResult {
        await execute(Paths.sketchybar, arguments)
    }

    public func yabaiRules() async -> CommandResult {
        await execute(Paths.yabai, ["-m", "rule", "--list"])
    }

    public func globalDefault(_ key: String) async -> CommandResult {
        await execute(Paths.defaults, ["read", "-g", key])
    }

    public func setGlobalDefault(_ key: String, float value: String) async -> CommandResult {
        await execute(Paths.defaults, ["write", "-g", key, "-float", value])
    }

    public func removeGlobalDefault(_ key: String) async -> CommandResult {
        await execute(Paths.defaults, ["delete", "-g", key])
    }

    public func applyTheme(named name: String) async -> CommandResult {
        await ThemeApplication(integrations: self).apply(name: name)
    }

    public func state(of daemon: Daemon) async -> DaemonState {
        let target = "gui/\(getuid())/\(daemon.launchdLabel)"
        let result = await execute(Paths.launchctl, ["print", target])
        guard result.ok else { return .stopped }

        // `launchctl print` emits "state = running" and "pid = 83970" on their own lines.
        var isRunning = false
        var pid: Int?
        for line in result.stdout.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "state = running" { isRunning = true }
            if trimmed.hasPrefix("pid = ") { pid = Int(trimmed.dropFirst(6)) }
        }
        if isRunning, let pid { return .running(pid: pid) }
        return isRunning ? .unknown : .stopped
    }

    /// The app that currently holds Secure Keyboard Entry, or `nil` when it is
    /// off.
    public func secureInput() async -> SecureInput? {
        await SecureInput.current(execute: execute)
    }

    /// Restarts a daemon and waits to see whether it actually survived.
    ///
    /// `kickstart` exits 0 the moment launchd has *spawned* the job, which says
    /// nothing about what happened next. skhd aborts within milliseconds when
    /// Secure Keyboard Entry is on, and reporting that spawn as a success is
    /// how a stopped service came to sit under a green console line.
    ///
    /// The polling defaults are loose enough for a slow starter and tight
    /// enough that a person does not notice; tests pass their own.
    public func restart(
        _ daemon: Daemon, attempts: Int = 8, settle: Duration = .milliseconds(120)
    ) async -> CommandResult {
        if let blocked = await refusedStart(daemon) { return blocked }
        // -k kills then restarts; matches what yabairc now does for borders on wake.
        let kickstart = await execute(
            Paths.launchctl,
            ["kickstart", "-k", "gui/\(getuid())/\(daemon.launchdLabel)"])
        guard kickstart.ok else { return kickstart }
        // A daemon on its way out can still read as running for the first
        // instant after the spawn, so "running" has to hold across two reads
        // before it counts as a start.
        var consecutive = 0
        for _ in 0..<max(1, attempts) {
            try? await Task.sleep(for: settle)
            consecutive = await state(of: daemon).isRunning ? consecutive + 1 : 0
            if consecutive >= 2 { return kickstart }
        }
        return await startupFailure(daemon, kickstart: kickstart)
    }

    /// Secure input is the one condition that makes a start pointless rather
    /// than merely uncertain, so it is checked before launchd is asked to do
    /// work that cannot succeed.
    private func refusedStart(_ daemon: Daemon) async -> CommandResult? {
        guard daemon == .skhd, let holder = await secureInput() else { return nil }
        return CommandResult(
            command: "restart \(daemon.rawValue)", status: 1,
            stderr: "\(holder.explanation) \(daemon.displayName) cannot start until it is off.")
    }

    /// The job spawned and died. launchd keeps no record of why, but every one
    /// of these daemons redirects its own stderr to a file, and the reason is
    /// the last line of it.
    private func startupFailure(_ daemon: Daemon, kickstart: CommandResult) async -> CommandResult {
        let reason = await lastErrorLine(of: daemon) ?? "It started and stopped immediately."
        return CommandResult(
            command: kickstart.command, status: 1,
            stderr: "\(daemon.displayName) did not stay running. \(reason)")
    }

    /// `launchctl list` prints the job's own `StandardErrorPath`, so the log is
    /// found rather than hard-coded: the four daemons each put theirs somewhere
    /// different, and a wrong guess would report silence as the diagnosis.
    private func lastErrorLine(of daemon: Daemon) async -> String? {
        let job = await execute(Paths.launchctl, ["list", daemon.launchdLabel])
        guard job.ok, let path = Self.standardErrorPath(inJobDescription: job.stdout)
        else { return nil }
        let tail = await execute(Paths.tail, ["-n", "1", path])
        guard tail.ok, !tail.stdout.isEmpty else { return nil }
        return tail.stdout
    }

    static func standardErrorPath(inJobDescription description: String) -> String? {
        guard let match = description.firstMatch(of: /"StandardErrorPath"\s*=\s*"([^"]+)"/)
        else { return nil }
        return String(match.1)
    }

    public func stop(_ daemon: Daemon) async -> CommandResult {
        await execute(
            Paths.launchctl,
            ["kill", "SIGTERM", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }
}
