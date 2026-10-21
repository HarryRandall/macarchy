import Foundation
import Testing
@testable import Macarchy

struct CommandRunnerTests {
    @Test func drainsLargeStderrWithoutDeadlock() async {
        let result = await CommandRunner.run(
            "/bin/bash", ["-c", "printf ready; head -c 200000 /dev/zero >&2"], timeout: 3)
        #expect(result.ok)
        #expect(result.stdout == "ready")
        #expect(result.stderr.utf8.count == 200000)
    }
    @Test func timeoutStopsProcess() async {
        let result = await CommandRunner.run("/bin/sleep", ["10"], timeout: 0.1)
        #expect(!result.ok)
        #expect(result.stderr.contains("Timed out"))
    }
    @Test func cancellationStopsProcess() async throws {
        let task = Task { await CommandRunner.run("/bin/sleep", ["10"]) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        let result = await task.value
        #expect(!result.ok)
        #expect(result.stderr.contains("Cancelled"))
    }
    @Test func timeoutStopsChildProcesses() async throws {
        let marker = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-child-\(UUID())")
        defer { try? FileManager.default.removeItem(at: marker) }
        // The child would write the marker after the parent has been stopped.
        let result = await CommandRunner.run(
            "/bin/bash", ["-c", "(sleep 0.6; touch '\(marker.path)') & wait"], timeout: 0.2)
        #expect(!result.ok)
        try await Task.sleep(for: .milliseconds(900))
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }
}
