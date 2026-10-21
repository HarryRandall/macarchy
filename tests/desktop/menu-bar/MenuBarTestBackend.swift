import Foundation
@testable import Macarchy

actor MenuBarTestBackend {
    nonisolated var integration: Integrations {
        Integrations { _, arguments in await self.sketchybar(arguments) }
    }
    var names = ["calendar"]
    var writes: [[String]] = []
    var failWrites = false
    var failedQueriesRemaining = 0
    func failQueries(_ count: Int) { failedQueriesRemaining = count }
    func setFailure(_ value: Bool) { failWrites = value }
    func recordedWrites() -> [[String]] { writes }
    func result(_ stdout: String = "", failure: Bool = false) -> CommandResult {
        CommandResult(
            command: "test", status: failure ? 1 : 0, stdout: stdout,
            stderr: failure ? "Test failure" : "")
    }
    func sketchybar(_ arguments: [String]) async -> CommandResult {
        if arguments == ["--query", "bar"] {
            guard
                let data = try? JSONSerialization.data(withJSONObject: [
                    "height": 35, "items": names
                ]),
                let text = String(data: data, encoding: .utf8)
            else { return result(failure: true) }
            return result(text)
        }
        if arguments.first == "--query" {
            if failedQueriesRemaining > 0 {
                failedQueriesRemaining -= 1; return result(failure: true)
            }
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
}
