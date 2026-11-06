import Foundation
import Testing

@testable import App
@testable import Macarchy

/// Answers every executable the app might call, through
/// `Integrations(execute:)`, and records each call. Scripted responders
/// answer first; then yabai's `-m config` is emulated; anything else fails
/// as if the tool were missing.
actor FakeDesktop {
    struct Call: Sendable, Equatable {
        let path: String
        let arguments: [String]
        /// The executable's name, such as `yabai` or `launchctl`.
        var tool: String { URL(fileURLWithPath: path).lastPathComponent }
    }

    /// What a scripted executable prints and exits with.
    struct Reply: Sendable {
        var status: Int32 = 0
        var stdout = ""
        var stderr = ""

        static func success(_ stdout: String = "") -> Reply { Reply(stdout: stdout) }
        static func failure(_ stderr: String, status: Int32 = 1) -> Reply {
            Reply(status: status, stderr: stderr)
        }
    }

    /// Answers one call's arguments, or returns nil to leave it to the next.
    typealias Responder = @Sendable (_ arguments: [String]) -> Reply?

    var config: [String: String] = [
        "layout": "bsp", "split_type": "auto", "window_placement": "second_child",
        "auto_balance": "off", "window_gap": "8", "top_padding": "8", "bottom_padding": "8",
        "left_padding": "8", "right_padding": "8", "mouse_modifier": "ctrl",
        "mouse_follows_focus": "off", "mouse_drop_action": "stack"
    ]
    private(set) var calls: [Call] = []
    var running = true
    var rejected: [String: String] = [:]
    private var responders: [String: [Responder]] = [:]

    func set(_ key: String, _ value: String) { config[key] = value }
    /// yabai stops responding, to scripted calls as well.
    func stop() { running = false }
    func reject(_ key: String, message: String) { rejected[key] = message }

    /// Answers calls to `tool` with `respond`. The latest responder asks first.
    func answer(_ tool: String, _ respond: @escaping Responder) {
        responders[tool, default: []].insert(respond, at: 0)
    }

    /// Answers calls to `tool` with exactly `arguments` with `reply`.
    func answer(_ tool: String, _ arguments: [String], with reply: Reply) {
        answer(tool) { $0 == arguments ? reply : nil }
    }

    /// The arguments of every call to `tool`, in order.
    func calls(to tool: String) -> [[String]] {
        calls.filter { $0.tool == tool }.map(\.arguments)
    }

    /// `-m config <key> <value>` calls, as `[key, value]`.
    var writes: [[String]] {
        calls.filter { $0.tool == "yabai" && $0.arguments.count == 4 }
            .map { Array($0.arguments[2...]) }
    }

    func run(_ path: String, _ arguments: [String]) -> CommandResult {
        let call = Call(path: path, arguments: arguments)
        calls.append(call)
        let command = ([path] + arguments).joined(separator: " ")
        if call.tool == "yabai", !running {
            return CommandResult(
                command: command, status: 1, stderr: "yabai-msg: failed to connect")
        }
        for respond in responders[call.tool] ?? [] {
            if let reply = respond(arguments) {
                return CommandResult(
                    command: command, status: reply.status, stdout: reply.stdout,
                    stderr: reply.stderr)
            }
        }
        guard call.tool == "yabai" else {
            return CommandResult(command: command, status: 127, stderr: "Not available in tests.")
        }
        return yabaiConfig(command, arguments)
    }

    private func yabaiConfig(_ command: String, _ arguments: [String]) -> CommandResult {
        guard arguments.count >= 3, arguments[0] == "-m", arguments[1] == "config" else {
            return CommandResult(command: command, status: 1, stderr: "unexpected")
        }
        let key = arguments[2]
        if arguments.count == 4 {
            if let message = rejected[key] {
                return CommandResult(command: command, status: 1, stderr: message)
            }
            config[key] = arguments[3]
            return CommandResult(command: command, status: 0)
        }
        return CommandResult(command: command, status: 0, stdout: config[key] ?? "")
    }
}

/// Records the switcher's theme actions instead of changing the desktop.
@MainActor
final class ThemeRecorder {
    var applied: [String] = []
    var backgrounds: [(theme: String, path: String)] = []
    var closeRequests = 0
    /// How many times the switcher ordered its panel in; it never really does.
    var presentations = 0
    /// When set, every recorded action fails with this on stderr.
    var failure: String?

    var actions: ThemeActions {
        ThemeActions(
            apply: { [weak self] _, name in
                self?.applied.append(name)
                return self?.result("theme \(name)") ?? CommandResult(command: "", status: 0)
            },
            useBackground: { [weak self] _, name, path in
                self?.backgrounds.append((name, path))
                return self?.result("wallpaper \(name) \(path)")
                    ?? CommandResult(command: "", status: 0)
            })
    }

    private func result(_ command: String) -> CommandResult {
        guard let failure else { return CommandResult(command: command, status: 0) }
        return CommandResult(command: command, status: 1, stderr: failure)
    }

    /// Production `close()` does nothing while the panel is hidden, and
    /// showing it would order a window on screen, so the page's request is
    /// counted here and handed to the same method.
    func recordCloses(of switcher: ThemeSwitcher) throws {
        let surface = try #require(switcher.surface)
        surface.router.register("switcher.close") { [weak switcher] (_: Empty) in
            self.closeRequests += 1
            switcher?.close()
            return Null()
        }
    }
}
