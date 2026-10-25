import Foundation
import Testing

@testable import Macarchy

struct StartupSignalsTests {
    @Test("startup registers every focus and Space signal under a Macarchy label")
    func signalsAreRegistered() {
        let labels = Startup.signals.compactMap { arguments in
            arguments.first { $0.hasPrefix("label=") }.map { String($0.dropFirst(6)) }
        }
        #expect(
            Set(labels) == [
                "macarchy_mission_control_exit", "macarchy_refocus_space",
                "macarchy_window_created", "macarchy_window_deminimized",
                "macarchy_refocus_destroyed", "macarchy_refocus_terminated"
            ])
        let missionControl = Startup.signals.first { $0.contains("event=mission_control_exit") }
        #expect(missionControl?.last?.contains("--focus \"$id\"") == true)
        #expect(missionControl?.last?.contains("widget trigger space_changed") == true)
    }

    /// Runs the Mission Control action against a fake yabai that reports the
    /// given focused window and visible Space, and returns its focus commands.
    private func missionControlFocus(
        window: (id: Int, space: Int)?, visible: Int
    ) async throws -> [String] {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-signals-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let log = root.appending(path: "focus.log")
        let windowJSON = window.map {
            "{\n\t\"id\":\($0.id),\n\t\"pid\":7,\n\t\"space\":\($0.space),\n}"
        }
        let fake = root.appending(path: "yabai")
        try """
        #!/bin/sh
        case "$*" in
          "-m query --spaces --space") printf '{\\n\\t"id":3,\\n\\t"index":\(visible),\\n}\\n' ;;
          "-m query --windows --window") \(windowJSON.map { "printf '%s\\n' '\($0)'" } ?? "exit 1") ;;
          "-m window --focus "*) echo "$4" >> \(Shell.quote(log.path)) ;;
        esac
        """.write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)

        let action = try #require(
            Startup.signals.first { $0.contains("event=mission_control_exit") }?.last)
        let script = String(action.dropFirst("action=".count))
            .replacingOccurrences(of: Shell.quote(Paths.yabai), with: Shell.quote(fake.path))
            .replacingOccurrences(
                of: Shell.quote(Paths.appLink.appending(path: "Contents/MacOS/macarchy").path),
                with: "true"
            )
            .replacingOccurrences(of: "sleep 0.25", with: "true")
        let result = await CommandRunner.run("/bin/sh", ["-c", script])
        #expect(result.ok, "\(result.stderr)")
        let focused = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        return focused.split(separator: "\n").map(String.init)
    }

    @Test("leaving Mission Control re-asserts a focused window on the visible Space")
    func reassertsWindowHere() async throws {
        #expect(try await missionControlFocus(window: (42, 2), visible: 2) == ["42"])
    }

    /// Focusing a window on another Space switches back to it, which would undo
    /// the Space chosen in Mission Control.
    @Test("leaving Mission Control leaves a stale window on another Space alone")
    func ignoresWindowElsewhere() async throws {
        #expect(try await missionControlFocus(window: (42, 1), visible: 3).isEmpty)
    }

    @Test("leaving Mission Control with nothing focused focuses a window here")
    func fillsInFocus() async throws {
        #expect(try await missionControlFocus(window: nil, visible: 3) == ["first"])
    }
}
