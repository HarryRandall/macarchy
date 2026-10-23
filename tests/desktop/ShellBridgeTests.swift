import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

/// The shell's handlers that touch neither preferences nor a window. Every
/// command reaches a fake, and Finder and quitting are recorded instead.
@MainActor
struct ShellBridgeTests {
    @MainActor
    private final class Count {
        var value = 0
    }

    @MainActor
    private final class Recorder {
        let reveals = Count()
        let quits = Count()

        var actions: ShellActions {
            ShellActions(
                revealSettings: { [reveals] in reveals.value += 1 },
                quit: { [quits] in quits.value += 1 })
        }
    }

    private static let unavailable: Integrations.Execute = { path, _ in
        CommandResult(command: path, status: 127, stderr: "Not available in tests.")
    }

    private func makeModel(_ execute: @escaping Integrations.Execute) -> AppModel {
        let store = SettingsStore(
            url: FileManager.default.temporaryDirectory
                .appending(path: "shell-bridge-\(UUID())/settings.json"))
        return AppModel(backend: Integrations(execute: execute), settingsStore: store)
    }

    private func makeRouter(_ model: AppModel, _ recorder: Recorder = Recorder()) -> BridgeRouter {
        _ = NSApplication.shared
        let router = BridgeRouter()
        router.registerShell(
            model: model, surface: WebSurface(surface: .settings), actions: recorder.actions)
        return router
    }

    private func reply(_ router: BridgeRouter, _ method: String) async throws -> [String: Any] {
        let json = await router.handle(["method": method, "params": [String: Any]()])
        return try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test("the log reads oldest first with categories and explicit nulls, and clears")
    func log() async throws {
        let model = makeModel(Self.unavailable)
        let router = makeRouter(model)
        model.log.note("theme lumon")
        model.log.record(
            CommandResult(command: "sketchybar --reload", status: 1, stderr: "No configuration"))
        model.log.failure("read layout", "yabai-msg: failed to connect")

        let read = try await reply(router, "shell.getLog")
        let value = try #require(read["value"] as? [String: Any])
        let entries = try #require(value["entries"] as? [[String: Any]])
        #expect(entries.map { $0["category"] as? String } == ["Themes", "Menu Bar", "Layout"])
        #expect(entries.map { $0["ok"] as? Bool } == [true, false, false])
        #expect(entries[0]["status"] is NSNull)
        #expect(entries[1]["status"] as? Int == 1)
        #expect(entries[1]["detail"] as? String == "Standard error:\nNo configuration")
        #expect(entries.map { $0["id"] as? String } == model.log.entries.map(\.id.uuidString))
        #expect(model.log.entries.count == 3)

        let cleared = try await reply(router, "shell.clearLog")
        #expect(cleared["ok"] as? Bool == true)
        #expect(model.log.entries.isEmpty)
    }

    @Test("restart all restarts every service in turn and names the ones that did not come back")
    func restartAll() async throws {
        let model = makeModel { path, arguments in
            let tool = URL(fileURLWithPath: path).lastPathComponent
            guard tool == "launchctl", let target = arguments.last else {
                return CommandResult(command: tool, status: 127)
            }
            let skhd = target.contains("skhd")
            switch arguments.first {
            case "kickstart":
                return CommandResult(
                    command: "launchctl kickstart", status: skhd ? 1 : 0,
                    stderr: skhd ? "Could not find service" : "")
            case "print" where !skhd:
                return CommandResult(
                    command: "launchctl print", status: 0, stdout: "state = running\npid = 42")
            default:
                return CommandResult(command: "launchctl", status: 113)
            }
        }
        let router = makeRouter(model)

        let restart = try await reply(router, "shell.restartAll")
        let value = try #require(restart["value"] as? [String: Any])
        #expect(value["outcome"] as? String == "Restarted 3 of 4 services; skhd did not restart.")
        #expect(model.daemons.runningCount == 3)
        #expect(model.daemons.states[.skhd] == .stopped)
        #expect(model.log.entries.count == 4)
    }

    @Test("the restart outcome is one sentence naming every service that failed")
    func restartOutcome() {
        func outcome(failing: Set<Daemon>) -> String {
            DaemonMonitor.outcome(
                of: Daemon.allCases.map { daemon in
                    let status: Int32 = failing.contains(daemon) ? 1 : 0
                    let result = CommandResult(command: daemon.rawValue, status: status)
                    return (daemon: daemon, result: result)
                })
        }
        #expect(outcome(failing: []) == "Restarted all 4 services.")
        #expect(outcome(failing: Set(Daemon.allCases)) == "None of the 4 services restarted.")
        #expect(
            outcome(failing: [.borders, .skhd])
                == "Restarted 2 of 4 services; borders and skhd did not restart.")
        #expect(
            outcome(failing: [.yabai, .borders, .sketchybar])
                == "Restarted 1 of 4 services; yabai, borders and SketchyBar did not restart.")
    }

    @Test("reveal and quit go through the injected actions")
    func actions() async throws {
        let model = makeModel(Self.unavailable)
        let recorder = Recorder()
        let router = makeRouter(model, recorder)

        let reveal = try await reply(router, "shell.revealSettings")
        #expect(reveal["ok"] as? Bool == true)
        #expect(recorder.reveals.value == 1)
        #expect(model.log.latest?.command == "reveal settings")

        let quit = try await reply(router, "shell.quit")
        #expect(quit["ok"] as? Bool == true)
        #expect(recorder.quits.value == 1)
    }

    @Test("a burst of log entries is announced once, and a later change again")
    func logBroadcast() async throws {
        let log = CommandLog()
        let broadcast = LogBroadcast(delay: .milliseconds(20))
        let (events, sink) = AsyncStream.makeStream(of: Void.self)
        let sent = Count()
        broadcast.start(log) {
            sent.value += 1
            sink.yield()
        }
        var received = events.makeAsyncIterator()

        // Observation is one-shot and re-armed on a later turn, so these
        // synchronous notes can only produce one event.
        for index in 0..<5 { log.note("note \(index)") }
        _ = await received.next()
        #expect(sent.value == 1)

        log.clear()
        _ = await received.next()
        #expect(sent.value == 2)
    }
}
