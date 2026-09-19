import Foundation
import Darwin

public struct CommandResult: Sendable {
    public let command: String
    public let status: Int32
    public let stdout: String
    public let stderr: String
    public var ok: Bool { status == 0 }
    public var summary: String { ok ? stdout : stderr }

    public init(command: String, status: Int32, stdout: String = "", stderr: String = "") {
        self.command = command; self.status = status; self.stdout = stdout; self.stderr = stderr
    }
}

/// Runs executables directly. Output files avoid pipe backpressure deadlocks.
public enum CommandRunner {
    public static func run(
        _ executable: String, _ arguments: [String], timeout: TimeInterval = 30
    ) async -> CommandResult {
        let cancellation = CancellationFlag()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(
                        returning: execute(executable, arguments, timeout, cancellation))
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func execute(
        _ executable: String, _ arguments: [String], _ timeout: TimeInterval,
        _ cancellation: CancellationFlag
    ) -> CommandResult {
        let command = ([URL(fileURLWithPath: executable).lastPathComponent] + arguments).joined(
            separator: " ")
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-process-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let outURL = root.appending(path: "stdout")
            let errURL = root.appending(path: "stderr")
            try Data().write(to: outURL); try Data().write(to: errURL)
            let out = try FileHandle(forWritingTo: outURL)
            let err = try FileHandle(forWritingTo: errURL)
            defer { try? out.close(); try? err.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = out; process.standardError = err
            if cancellation.isCancelled { throw CancellationError() }
            try process.run()
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            var interrupted = false
            while process.isRunning {
                if cancellation.isCancelled || ProcessInfo.processInfo.systemUptime >= deadline {
                    interrupted = true
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    break
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
            process.waitUntilExit()
            let stdout = try readOutput(outURL)
            let stderr = try readOutput(errURL)
            return CommandResult(
                command: command, status: interrupted ? -1 : process.terminationStatus,
                stdout: stdout,
                stderr: interrupted
                    ? (cancellation.isCancelled ? "Cancelled: \(command)" : "Timed out: \(command)")
                    : stderr)
        } catch {
            return CommandResult(command: command, status: -1, stderr: error.localizedDescription)
        }
    }

    private static func readOutput(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 4 * 1024 * 1024) ?? Data()
        // Preserve diagnostics even when a process emits invalid UTF-8.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Cancellation crosses the task/Dispatch boundary; every access holds the lock.
private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
}
