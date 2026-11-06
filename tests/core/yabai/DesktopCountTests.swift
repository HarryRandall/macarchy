import Foundation
import Testing

@testable import Macarchy

struct DesktopCountTests {
    private func count(status: Int32 = 0, stdout: String) async -> (Int?, [String]) {
        let asked = LockedArguments()
        let integrations = Integrations { _, arguments in
            await asked.set(arguments)
            return CommandResult(command: "yabai", status: status, stdout: stdout)
        }
        let count = await integrations.desktopCount()
        return (count, await asked.value)
    }

    @Test("counts the Spaces yabai lists across every display")
    func countsSpaces() async {
        let spaces = #"[{"index":1,"display":1},{"index":2,"display":1},{"index":3,"display":2}]"#
        let (count, arguments) = await count(stdout: spaces)
        #expect(count == 3)
        #expect(arguments == ["-m", "query", "--spaces"])
    }

    @Test("is unknown when yabai is not running or answers with something else")
    func unknown() async {
        #expect(await count(status: 1, stdout: "").0 == nil)
        #expect(await count(stdout: "yabai-msg: failed to connect").0 == nil)
        #expect(await count(stdout: #"{"index":1}"#).0 == nil)
    }
}

private actor LockedArguments {
    var value: [String] = []
    func set(_ arguments: [String]) { value = arguments }
}
