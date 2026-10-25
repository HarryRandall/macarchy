import Foundation
import Testing

@testable import Macarchy

struct DiagnosticsTests {
    @Test("the home folder and username are removed from reports")
    func redactsIdentity() {
        let text = "Failed at \(Paths.home.path)/x for \(NSUserName())"
        let redacted = Diagnostics.redact(text)
        #expect(!redacted.contains(Paths.home.path))
        #expect(!redacted.contains(" \(NSUserName())"))
    }

    @Test("bash syntax errors keep only their line number")
    func syntaxErrorsAreReduced() async {
        let file = FileManager.default.temporaryDirectory.appending(path: "bad-\(UUID()).sh")
        defer { try? FileManager.default.removeItem(at: file) }
        try? "#!/bin/bash\ncurl -H 'Authorization: Bearer SECRET' $(\n".write(
            to: file, atomically: true, encoding: .utf8)
        let result = await CommandRunner.run("/bin/bash", ["-n", file.path])
        #expect(!result.ok)
        #expect(result.stderr.range(of: "line [0-9]+", options: .regularExpression) != nil)
    }

    @Test("a running daemon passes only once that copy has run its startup file")
    func startupRuns() {
        func check(ours: Bool = true, recorded: Int?, seconds: Int?) -> HealthCheck.Status? {
            Doctor.startupCheck(
                .yabai, ours: ours, pid: 42, recorded: recorded, secondsRunning: seconds)?.status
        }
        #expect(check(recorded: 42, seconds: nil) == .passed)
        #expect(check(recorded: 41, seconds: 600) == .failed)
        #expect(check(recorded: nil, seconds: nil) == .failed)
        #expect(check(recorded: nil, seconds: 3) == .unknown)
        #expect(check(ours: false, recorded: nil, seconds: 600) == nil)
        #expect(
            Doctor.startupCheck(.skhd, ours: true, pid: 42, recorded: nil, secondsRunning: 600)
                == nil)
    }

    @Test("ps elapsed times read as seconds")
    func elapsedTimes() {
        #expect(Doctor.elapsedSeconds("   00:07\n") == 7)
        #expect(Doctor.elapsedSeconds("01:02:03") == 3723)
        #expect(Doctor.elapsedSeconds("2-00:00:01") == 172_801)
        #expect(Doctor.elapsedSeconds("") == nil)
        #expect(Doctor.elapsedSeconds("soon") == nil)
    }

    @Test("window signals count as registered only when both helpers are loaded")
    func windowSignals() async {
        func registered(_ list: String) async -> Bool {
            await Doctor.windowSignalsRegistered(
                integrations: Integrations(execute: { _, _ in
                    CommandResult(command: "mock", status: 0, stdout: list)
                }))
        }
        #expect(!(await registered(#"[{"label":"macarchy_window_created"}]"#)))
        #expect(
            await registered(
                #"[{"label":"macarchy_window_created"},{"label":"macarchy_refocus_destroyed"}]"#))
        #expect(!(await registered("macarchy_window_created macarchy_refocus_destroyed")))
    }
}
