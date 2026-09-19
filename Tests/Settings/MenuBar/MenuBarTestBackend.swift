import Foundation
@testable import Desktop

actor MenuBarTestBackend: StackBackend {
    var names = ["calendar"]
    var writes: [[String]] = []
    var failWrites = false
    func setFailure(_ value: Bool) { failWrites = value }
    func recordedWrites() -> [[String]] { writes }
    func result(_ stdout: String = "", failure: Bool = false) -> CommandResult {
        CommandResult(
            command: "test", status: failure ? 1 : 0, stdout: stdout,
            stderr: failure ? "Test failure" : "")
    }
    func barState() async -> (CommandResult, BarState?) {
        let data = try? JSONSerialization.data(withJSONObject: ["height": 35, "items": names])
        return (result(), data.flatMap { try? JSONDecoder().decode(BarState.self, from: $0) })
    }
    func sketchybar(_ arguments: [String]) async -> CommandResult {
        if arguments.first == "--query" {
            return result(
                "{\"geometry\":{\"position\":\"right\",\"drawing\":\"on\"},\"bounding_rects\":{\"display-1\":{\"origin\":[100,0],\"size\":[100,35]}}}"
            )
        }
        writes.append(arguments)
        if failWrites { return result(failure: true) }
        if arguments.first == "--add", arguments.count > 2 { names.append(arguments[2]) }
        if arguments.first == "--remove", arguments.count > 1 {
            names.removeAll { $0 == arguments[1] }
        }
        return result()
    }
    func yabaiRead(_ key: String) async -> CommandResult { result() }
    func yabaiWrite(_ key: String, value: String) async -> CommandResult { result() }
    func borders(_ arguments: [String]) async -> CommandResult { result() }
    func yabaiRules() async -> CommandResult { result() }
    func globalDefault(_ key: String) async -> CommandResult { result() }
    func setGlobalDefault(_ key: String, float value: String) async -> CommandResult { result() }
    func removeGlobalDefault(_ key: String) async -> CommandResult { result() }
    func runScript(_ path: String) async -> CommandResult { result() }
    func applyTheme(named name: String) async -> CommandResult { result() }
    func state(of daemon: Daemon) async -> DaemonState { .stopped }
    func restart(_ daemon: Daemon) async -> CommandResult { result() }
    func stop(_ daemon: Daemon) async -> CommandResult { result() }
}
