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

    public func restart(_ daemon: Daemon) async -> CommandResult {
        // -k kills then restarts; matches what yabairc now does for borders on wake.
        await execute(
            Paths.launchctl,
            ["kickstart", "-k", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }

    public func stop(_ daemon: Daemon) async -> CommandResult {
        await execute(
            Paths.launchctl,
            ["kill", "SIGTERM", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }
}
