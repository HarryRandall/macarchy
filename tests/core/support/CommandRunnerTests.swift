import Darwin
import Foundation
import Testing
@testable import Macarchy

struct CommandRunnerTests {
    @Test func resultsWithoutSkippedPartsStillDecode() throws {
        let older = Data(#"{"command":"theme","status":0,"stdout":"Applied","stderr":""}"#.utf8)
        let result = try JSONDecoder().decode(CommandResult.self, from: older)
        #expect(result.ok && result.skipped.isEmpty)
        let partial = CommandResult(command: "theme", status: 0, skipped: ["borders"])
        let decoded = try JSONDecoder().decode(
            CommandResult.self, from: JSONEncoder().encode(partial))
        #expect(decoded.skipped == ["borders"])
    }

    @Test func drainsLargeStderrWithoutDeadlock() async {
        let result = await CommandRunner.run(
            "/bin/bash", ["-c", "printf ready; head -c 200000 /dev/zero >&2"], timeout: 3)
        #expect(result.ok)
        #expect(result.stdout == "ready")
        #expect(result.stderr.utf8.count == 200000)
    }
    @Test func reportsExitStatus() async {
        let result = await CommandRunner.run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"])
        #expect(result.status == 3)
        #expect(result.stdout == "out")
        #expect(result.stderr == "err")
    }
    @Test func timeoutStopsProcess() async {
        let result = await CommandRunner.run("/bin/sleep", ["10"], timeout: 0.1)
        #expect(!result.ok)
        #expect(result.stderr.contains("Timed out"))
    }
    @Test func cancellationStopsProcess() async throws {
        let readiness = try Readiness()
        defer { readiness.remove() }
        let task = Task {
            let result = await CommandRunner.run(
                "/bin/bash", ["-c", #"echo ready > "$0"; exec sleep 10"#, readiness.path])
            readiness.closeWriter()
            return result
        }
        #expect(await readiness.line() == "ready")
        task.cancel()
        let result = await task.value
        #expect(!result.ok)
        #expect(result.stderr.contains("Cancelled"))
    }
    @Test func timeoutStopsChildProcesses() async throws {
        let marker = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-child-\(UUID())")
        defer { try? FileManager.default.removeItem(at: marker) }
        let readiness = try Readiness()
        defer { readiness.remove() }
        // The child reports that it is running and keeps the pipe open for as
        // long as it and its own children live. It would write the marker
        // after the parent has been stopped.
        let script = #"( exec 3>"$0"; echo ready >&3; sleep 5; touch "$1" ) & wait"#
        let result = await CommandRunner.run(
            "/bin/bash", ["-c", script, readiness.path, marker.path], timeout: 1)
        #expect(!result.ok)
        readiness.closeWriter()
        // End of file means every writer has closed: the child has exited.
        #expect(
            await readiness.rest() == "ready\n", "the child was not running before the timeout")
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }
}

/// A named pipe a subprocess writes to once it is running. The test opens
/// both ends first, so a writer never blocks and reading waits for the
/// subprocess rather than seeing end of file before it connects. Once the
/// test closes its own write end, end of file means every other writer has
/// gone.
private struct Readiness {
    let path: String
    private let reader: Int32
    private let writer: Int32

    init() throws {
        path =
            FileManager.default.temporaryDirectory
            .appending(path: "macarchy-ready-\(UUID())").path
        try #require(mkfifo(path, 0o600) == 0)
        reader = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        writer = open(path, O_WRONLY | O_CLOEXEC)
        try #require(reader >= 0 && writer >= 0)
        _ = fcntl(reader, F_SETFL, fcntl(reader, F_GETFL) & ~O_NONBLOCK)
    }

    /// The first line written, or what there was once every writer closed.
    func line() async -> String { await read(toNewline: true) }

    /// Everything written, once every writer has closed.
    func rest() async -> String { await read(toNewline: false) }

    func closeWriter() { close(writer) }

    func remove() {
        close(reader)
        unlink(path)
    }

    private func read(toNewline: Bool) async -> String {
        let reader = reader
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var bytes: [UInt8] = []
                var byte: UInt8 = 0
                while Darwin.read(reader, &byte, 1) == 1 {
                    if toNewline, byte == UInt8(ascii: "\n") { break }
                    bytes.append(byte)
                }
                continuation.resume(returning: String(bytes: bytes, encoding: .utf8) ?? "")
            }
        }
    }
}
