import Foundation

/// The seam between the UI and the desktop stack.
///
/// Today this is four Homebrew CLIs. If the stack is ever collapsed into a
/// single daemon — or the daemons are replaced outright — this protocol is the
/// only thing that has to change; no view or model talks to a process directly.
protocol StackBackend: Sendable {
    // yabai is the only daemon that reads back config, which is why the Layout
    // pane can hydrate from what is actually running rather than from a file.
    func yabaiRead(_ key: String) async -> CommandResult
    func yabaiWrite(_ key: String, value: String) async -> CommandResult

    // borders has no query verb — write-only, so the settings store stays authoritative.
    func borders(_ arguments: [String]) async -> CommandResult

    func barState() async -> (CommandResult, BarState?)

    func applyTheme(named name: String) async -> CommandResult

    func state(of daemon: Daemon) async -> DaemonState
    func restart(_ daemon: Daemon) async -> CommandResult
    func stop(_ daemon: Daemon) async -> CommandResult
}

/// Subset of `sketchybar --query bar` that the Menu Bar pane cares about.
struct BarState: Codable, Sendable {
    var height: Int?
    var position: String?
    var blurRadius: Int?
    var sticky: String?
    var color: String?
    var items: [String]?
    var paddingLeft: Int?
    var paddingRight: Int?
    var cornerRadius: Int?
    var yOffset: Int?

    enum CodingKeys: String, CodingKey {
        case height, position, sticky, color, items
        case blurRadius = "blur_radius"
        case paddingLeft = "padding_left"
        case paddingRight = "padding_right"
        case cornerRadius = "corner_radius"
        case yOffset = "y_offset"
    }
}

struct CLIBackend: StackBackend {
    func yabaiRead(_ key: String) async -> CommandResult {
        await CommandRunner.run(Paths.yabai, ["-m", "config", key])
    }

    func yabaiWrite(_ key: String, value: String) async -> CommandResult {
        await CommandRunner.run(Paths.yabai, ["-m", "config", key, value])
    }

    func borders(_ arguments: [String]) async -> CommandResult {
        await CommandRunner.run(Paths.borders, arguments)
    }

    func barState() async -> (CommandResult, BarState?) {
        let result = await CommandRunner.run(Paths.sketchybar, ["--query", "bar"])
        guard result.ok, let data = result.stdout.data(using: .utf8) else { return (result, nil) }
        return (result, try? JSONDecoder().decode(BarState.self, from: data))
    }

    func applyTheme(named name: String) async -> CommandResult {
        await CommandRunner.run(Paths.themeSwitch, [name])
    }

    func state(of daemon: Daemon) async -> DaemonState {
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

    func restart(_ daemon: Daemon) async -> CommandResult {
        // -k kills then restarts; matches what yabairc now does for borders on wake.
        await CommandRunner.run(Paths.launchctl,
                                ["kickstart", "-k", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }

    func stop(_ daemon: Daemon) async -> CommandResult {
        await CommandRunner.run(Paths.launchctl,
                                ["kill", "SIGTERM", "gui/\(getuid())/\(daemon.launchdLabel)"])
    }
}
