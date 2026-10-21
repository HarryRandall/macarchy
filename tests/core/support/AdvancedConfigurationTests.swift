import Foundation
import Testing

@testable import Macarchy

private actor MaintenanceRecorder {
    var calls: [[String]] = []
    var secureReads = 0
    func run(_ path: String, _ arguments: [String]) -> CommandResult {
        calls.append([path] + arguments)
        if path == Paths.ioreg {
            secureReads += 1
            let output =
                secureReads == 1
                ? "\"kCGSSessionSecureInputPID\" = \(ProcessInfo.processInfo.processIdentifier)"
                : ""
            return CommandResult(command: path, status: 0, stdout: output)
        }
        if arguments.first == "print" {
            return CommandResult(command: path, status: 0, stdout: "state = running\npid = 123")
        }
        return CommandResult(command: path, status: 0)
    }
}

struct AdvancedConfigurationTests {
    @MainActor
    @Test("restarting skhd yields and returns focus only when this process holds Secure Input")
    func secureInputHandoff() async {
        let recorder = MaintenanceRecorder()
        var focus: [String] = []
        let services = DesktopServices(
            integrations: Integrations { await recorder.run($0, $1) },
            deactivate: { focus.append("yield") }, activate: { focus.append("return") })
        let result = await services.restart(.skhd)
        #expect(result.ok)
        #expect(focus == ["yield", "return"])
        #expect(await recorder.calls.contains { $0.contains("kickstart") })
        focus.removeAll()
        _ = await services.restart(.borders)
        #expect(focus.isEmpty)
        _ = await services.stop(.yabai)
        #expect(await recorder.calls.last?.contains("SIGTERM") == true)
    }

    @Test("snapshot identifiers cannot name arbitrary files")
    func unknownSnapshotRefused() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "advanced-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MaintenanceRecorder()
        let configuration = AdvancedConfiguration(
            integrations: Integrations { await recorder.run($0, $1) })
        await #expect(throws: ConfigurationError.self) {
            try await configuration.restoreSnapshot(
                id: "../../settings.json", store: SnapshotStore(root: root))
        }
        #expect(await recorder.calls.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("window signals require both registrations and tolerate unavailable yabai")
    func windowSignals() async {
        let incomplete = AdvancedConfiguration(
            integrations: Integrations { _, _ in
                CommandResult(
                    command: "signals", status: 0,
                    stdout: "[{\"label\":\"macarchy_window_created\"}]")
            })
        #expect(await !incomplete.wakeHelpersRegistered())
        let complete = AdvancedConfiguration(
            integrations: Integrations { _, _ in
                CommandResult(
                    command: "signals", status: 0,
                    stdout:
                        "[{\"label\":\"macarchy_window_created\"},{\"label\":\"macarchy_refocus_destroyed\"}]"
                )
            })
        #expect(await complete.wakeHelpersRegistered())
    }
}
