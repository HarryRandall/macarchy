import Testing
import Macarchy

@testable import App

@Suite("Console diagnostics")
@MainActor
struct CommandLogTests {
    @Test("Clearing an entry preserves the remaining activity")
    func removeEntry() throws {
        let log = CommandLog()
        log.note("loaded themes")
        let first = try #require(log.latest)
        log.note("parsed skhdrc")
        log.remove(first.id)
        #expect(log.entries.count == 1)
        #expect(log.latest?.command == "parsed skhdrc")
        log.remove(first.id)
        #expect(log.entries.count == 1)
    }

    @Test("Activity types distinguish the desktop integrations")
    func categories() {
        let log = CommandLog()
        let examples: [(String, ConsoleCategory)] = [
            ("sketchybar --query bar", .menuBar),
            ("borders width=6", .borders),
            ("loaded themes", .themes),
            ("parsed skhdrc", .shortcuts),
            ("Window rules unreadable", .rules),
            ("hydrated layout", .layout),
            ("restore failed", .backups),
            ("Settings unreadable", .system)
        ]
        for (command, category) in examples {
            log.note(command)
            #expect(log.latest?.category == category)
        }
    }

    @Test("Failures retain both output streams and their exit status")
    func failureOutput() {
        let log = CommandLog()
        log.record(
            CommandResult(command: "example", status: 7, stdout: "partial result", stderr: "failed")
        )
        #expect(log.latest?.ok == false)
        #expect(log.latest?.status == 7)
        #expect(log.latest?.detail.contains("partial result") == true)
        #expect(log.latest?.detail.contains("failed") == true)
        #expect(log.latest?.copyText.contains("Exit 7") == true)
    }

    @Test("Successful commands retain stderr diagnostics")
    func successDiagnostics() {
        let log = CommandLog()
        log.record(CommandResult(command: "example", status: 0, stderr: "warning"))
        #expect(log.latest?.ok == true)
        #expect(log.latest?.detail.contains("warning") == true)
    }

    @Test("History remains bounded and clearing allows new activity")
    func clearHistory() {
        let log = CommandLog()
        for index in 0..<205 { log.note("Read \(index)") }
        #expect(log.entries.count == 200)
        #expect(log.entries.first?.command == "Read 5")
        log.clear()
        #expect(log.latest == nil)
        log.note("Read again", "configuration")
        #expect(log.entries.count == 1)
        #expect(log.latest?.status == nil)
        #expect(log.latest?.copyText.contains("configuration") == true)
    }
}
