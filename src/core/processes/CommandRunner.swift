import Foundation
import Darwin

public struct CommandResult: Sendable, Codable {
    public let command: String
    public let status: Int32
    public let stdout: String
    public let stderr: String
    /// Optional parts an operation left out, such as a stopped service or a
    /// command an isolated run refused to run. A result can succeed with parts
    /// skipped; callers report that as partial.
    public let skipped: [String]
    public var ok: Bool { status == 0 }
    public var summary: String { ok ? stdout : stderr }

    public init(
        command: String, status: Int32, stdout: String = "", stderr: String = "",
        skipped: [String] = []
    ) {
        self.command = command; self.status = status; self.stdout = stdout; self.stderr = stderr
        self.skipped = skipped
    }

    /// Results are shared between processes through request files, and a
    /// build from before `skipped` existed writes none.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decode(String.self, forKey: .command)
        status = try container.decode(Int32.self, forKey: .status)
        stdout = try container.decode(String.self, forKey: .stdout)
        stderr = try container.decode(String.self, forKey: .stderr)
        skipped = try container.decodeIfPresent([String].self, forKey: .skipped) ?? []
    }
}

/// Runs executables directly. Output files avoid pipe backpressure deadlocks.
public enum CommandRunner {
    /// `environment` replaces the caller's, and `directory` is where the
    /// process starts; both default to what the caller has.
    public static func run(
        _ executable: String, _ arguments: [String], timeout: TimeInterval = 30,
        environment: [String: String]? = nil, directory: URL? = nil
    ) async -> CommandResult {
        if let reason = DesktopIsolation.refusal(executable, arguments) {
            let command = ([URL(fileURLWithPath: executable).lastPathComponent] + arguments)
                .joined(separator: " ")
            return CommandResult(command: command, status: 0, skipped: [reason])
        }
        let cancellation = CancellationFlag()
        let setup = Setup(environment: environment, directory: directory)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    continuation.resume(
                        returning: execute(executable, arguments, timeout, setup, cancellation))
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private struct Setup: Sendable {
        let environment: [String: String]?
        let directory: URL?
    }

    private static func execute(
        _ executable: String, _ arguments: [String], _ timeout: TimeInterval,
        _ setup: Setup, _ cancellation: CancellationFlag
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
            if let environment = setup.environment { process.environment = environment }
            if let directory = setup.directory { process.currentDirectoryURL = directory }
            process.standardOutput = out; process.standardError = err
            // Woken the moment the process exits. Polling `isRunning` and then
            // `waitUntilExit` added about 70 ms to every command, which the
            // bar showed as lag on each Space switch and dropdown highlight.
            let exited = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in exited.signal() }
            if cancellation.isCancelled { throw CancellationError() }
            try process.run()
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            var interrupted = false
            while exited.wait(timeout: .now() + 0.01) == .timedOut {
                if cancellation.isCancelled || ProcessInfo.processInfo.systemUptime >= deadline {
                    interrupted = true
                    // A shell helper's children would otherwise keep changing
                    // files after the caller was told the command stopped.
                    let tree = descendants(of: process.processIdentifier)
                    tree.forEach { kill($0, SIGTERM) }
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    tree.forEach { kill($0, SIGKILL) }
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    exited.wait()
                    break
                }
            }
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

    /// Every process below `pid`, deepest first.
    static func descendants(of pid: pid_t) -> [pid_t] {
        var buffer = [pid_t](repeating: 0, count: 256)
        let count = proc_listchildpids(
            pid, &buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }
        let children = buffer.prefix(Int(count)).filter { $0 > 0 }
        return children.flatMap { descendants(of: $0) + [$0] }
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
