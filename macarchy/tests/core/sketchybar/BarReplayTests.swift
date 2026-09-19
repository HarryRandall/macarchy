import Foundation
import Testing
@testable import Macarchy

private actor BarRecorder {
    var calls: [[String]] = []
    func execute(_ arguments: [String]) -> CommandResult {
        calls.append(arguments)
        return CommandResult(command: "test", status: arguments.first == "--query" ? 1 : 0)
    }
    func recorded() -> [[String]] { calls }
}

struct BarReplayTests {
    @Test("native startup creates custom items and sends labels literally")
    func replay() async throws {
        let recorder = BarRecorder()
        var configuration = BarConfiguration()
        var component = BarComponent(
            id: "macarchy.test", title: "Text", side: "right", members: ["macarchy.test"])
        component.kind = "text"
        component.text = "Harry's $(touch /tmp/never-execute)\n--remove calendar"
        configuration.components = [component]
        try await BarCommands.replay(
            configuration,
            integrations: Integrations { _, args in
                await recorder.execute(args)
            })
        let calls = await recorder.recorded()
        #expect(calls[0] == ["--query", "macarchy.test"])
        #expect(calls[1] == ["--add", "item", "macarchy.test", "right"])
        #expect(calls[2].contains("label=\(component.text)"))
    }

    @Test("invalid saved spacing is rejected before sending desktop commands")
    func invalid() async throws {
        let recorder = BarRecorder()
        var configuration = BarConfiguration()
        configuration.componentPadding = -1
        do {
            try await BarCommands.replay(
                configuration,
                integrations: Integrations { _, args in
                    await recorder.execute(args)
                })
            Issue.record("Invalid spacing was accepted")
        } catch {
            #expect(await recorder.recorded().isEmpty)
        }
    }
}
