import Foundation

/// The seam between the UI and the desktop stack.
///
/// Today this is four Homebrew CLIs. If the stack is ever collapsed into a
/// single daemon — or the daemons are replaced outright — this protocol is the
/// only thing that has to change; no view or model talks to a process directly.
public protocol StackBackend: Sendable {
    // yabai is the only daemon that reads back config, which is why the Layout
    // pane can hydrate from what is actually running rather than from a file.
    func yabaiRead(_ key: String) async -> CommandResult
    func yabaiWrite(_ key: String, value: String) async -> CommandResult

    // borders has no query verb — write-only, so the settings store stays authoritative.
    func borders(_ arguments: [String]) async -> CommandResult

    func barState() async -> (CommandResult, BarState?)

    /// Arbitrary sketchybar invocation — item queries, --bar, --set.
    func sketchybar(_ arguments: [String]) async -> CommandResult

    func yabaiRules() async -> CommandResult

    /// `defaults` on the global domain, for window-server settings that have no
    /// daemon behind them.
    func globalDefault(_ key: String) async -> CommandResult
    func setGlobalDefault(_ key: String, float value: String) async -> CommandResult
    func removeGlobalDefault(_ key: String) async -> CommandResult

    /// Helper scripts the stack still owns, such as sync_float_rules.sh.
    func runScript(_ path: String) async -> CommandResult

    func applyTheme(named name: String) async -> CommandResult

    func state(of daemon: Daemon) async -> DaemonState
    func restart(_ daemon: Daemon) async -> CommandResult
    func stop(_ daemon: Daemon) async -> CommandResult
}

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

public struct CLIBackend: StackBackend {
    public init() {}

    public func yabaiRead(_ key: String) async -> CommandResult {
        await CommandRunner.run(Paths.yabai, ["-m", "config", key])
    }

    public func yabaiWrite(_ key: String, value: String) async -> CommandResult {
        await CommandRunner.run(Paths.yabai, ["-m", "config", key, value])
    }

    public func borders(_ arguments: [String]) async -> CommandResult {
        await CommandRunner.run(Paths.borders, arguments)
    }

    public func barState() async -> (CommandResult, BarState?) {
        let result = await CommandRunner.run(Paths.sketchybar, ["--query", "bar"])
        guard result.ok, let data = result.stdout.data(using: .utf8) else { return (result, nil) }
        return (result, try? JSONDecoder().decode(BarState.self, from: data))
    }

    public func sketchybar(_ arguments: [String]) async -> CommandResult {
        await CommandRunner.run(Paths.sketchybar, arguments)
    }

    public func yabaiRules() async -> CommandResult {
        await CommandRunner.run(Paths.yabai, ["-m", "rule", "--list"])
    }

    public func globalDefault(_ key: String) async -> CommandResult {
        await CommandRunner.run(Paths.defaults, ["read", "-g", key])
    }

    public func setGlobalDefault(_ key: String, float value: String) async -> CommandResult {
        await CommandRunner.run(Paths.defaults, ["write", "-g", key, "-float", value])
    }

    public func removeGlobalDefault(_ key: String) async -> CommandResult {
        await CommandRunner.run(Paths.defaults, ["delete", "-g", key])
    }

    public func runScript(_ path: String) async -> CommandResult {
        await CommandRunner.run("/bin/bash", [path])
    }

    public func applyTheme(named name: String) async -> CommandResult {
        await CommandRunner.run(Paths.themeSwitch, [name])
    }

    public func state(of daemon: Daemon) async -> DaemonState {
        let target = "gui/\(getuid())/\(daemon.launchdLabel)"
        let result = await CommandRunner.run(Paths.launchctl, ["print", target])
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

    public func restart(_ daemon: Daemon) async -> CommandResult {
        // -k kills then restarts; matches what yabairc now does for borders on wake.
        await CommandRunner.run(
            Paths.launchctl,
            ["kickstart", "-k", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }

    public func stop(_ daemon: Daemon) async -> CommandResult {
        await CommandRunner.run(
            Paths.launchctl,
            ["kill", "SIGTERM", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }
}
