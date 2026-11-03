import Darwin
import Foundation

extension CommandRunner {
    /// Runs a long command whose progress a person watches, such as
    /// `brew install`, passing each line of its output to `line` as it
    /// arrives. Standard output and error are one stream, as in Terminal;
    /// the result holds all of it in `stdout` and, when the command fails,
    /// its last lines again in `stderr`. Isolation, timeouts and cancellation
    /// work as in `run`.
    public static func stream(
        _ executable: String, _ arguments: [String], timeout: TimeInterval = 1800,
        environment: [String: String]? = nil,
        line: @escaping @Sendable (String) -> Void
    ) async -> CommandResult {
        let command = ([URL(fileURLWithPath: executable).lastPathComponent] + arguments)
            .joined(separator: " ")
        if let reason = DesktopIsolation.refusal(executable, arguments) {
            return CommandResult(command: command, status: 0, skipped: [reason])
        }
        let job = StreamJob(
            executable: executable, arguments: arguments, command: command, timeout: timeout,
            environment: environment)
        let cancellation = CancellationFlag()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(
                        returning: streaming(job, cancellation: cancellation, line: line))
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private struct StreamJob: Sendable {
        let executable: String
        let arguments: [String]
        let command: String
        let timeout: TimeInterval
        let environment: [String: String]?
    }

    private static func streaming(
        _ job: StreamJob, cancellation: CancellationFlag,
        line: @escaping @Sendable (String) -> Void
    ) -> CommandResult {
        let command = job.command
        let pipe = Pipe()
        let lines = LineBuffer(line)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: job.executable)
        process.arguments = job.arguments
        if let environment = job.environment { process.environment = environment }
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            lines.append(handle.availableData)
        }
        do {
            if cancellation.isCancelled { throw CancellationError() }
            try process.run()
            // Only the child writes, so the end of its output is the end of the pipe.
            try? pipe.fileHandleForWriting.close()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return CommandResult(command: command, status: -1, stderr: error.localizedDescription)
        }
        let deadline = ProcessInfo.processInfo.systemUptime + job.timeout
        var interrupted = false
        while exited.wait(timeout: .now() + 0.05) == .timedOut {
            guard cancellation.isCancelled || ProcessInfo.processInfo.systemUptime >= deadline
            else { continue }
            interrupted = true
            let tree = descendants(of: process.processIdentifier)
            tree.forEach { kill($0, SIGTERM) }
            process.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                tree.forEach { kill($0, SIGKILL) }
                kill(process.processIdentifier, SIGKILL)
                exited.wait()
            } else {
                tree.forEach { kill($0, SIGKILL) }
            }
            break
        }
        pipe.fileHandleForReading.readabilityHandler = nil
        // Whatever arrived between the last read and the exit.
        lines.append(pipe.fileHandleForReading.readDataToEndOfFile())
        let output = lines.finish()
        let status = interrupted ? -1 : process.terminationStatus
        let tail = output.split(separator: "\n", omittingEmptySubsequences: true).suffix(12)
            .joined(separator: "\n")
        let reason =
            interrupted
            ? (cancellation.isCancelled ? "Cancelled: \(command)" : "Timed out: \(command)")
            : tail.isEmpty ? "\(command) exited with status \(status)" : tail
        return CommandResult(
            command: command, status: status, stdout: output, stderr: status == 0 ? "" : reason)
    }
}

/// Splits output into lines as it arrives from the reading queue, passing
/// each complete one on, and keeps all of it for the result.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()
    private var all = Data()
    private let line: @Sendable (String) -> Void

    init(_ line: @escaping @Sendable (String) -> Void) { self.line = line }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        let complete: [String] = lock.withLock {
            all.append(data)
            pending.append(data)
            var found: [String] = []
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                found.append(
                    Self.text(pending[pending.startIndex..<newline])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                pending.removeSubrange(pending.startIndex...newline)
            }
            return found
        }
        complete.forEach(line)
    }

    /// Passes on a last line without its newline and returns everything.
    func finish() -> String {
        let (rest, output) = lock.withLock {
            let rest = pending.isEmpty ? nil : Self.text(pending)
            pending = Data()
            return (rest, Self.text(all))
        }
        if let rest { line(rest) }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Output that is not UTF-8, such as a progress bar's bytes, is still shown.
    // swiftlint:disable:next optional_data_string_conversion
    private static func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
}
