import Foundation

public struct CommandResult: Sendable {
    public let command: String
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var ok: Bool { status == 0 }

    /// What the console strip shows: stdout when it succeeded, stderr when it didn't.
    public var summary: String { ok ? stdout : stderr }
}

/// Thin async wrapper over `Process`. Everything the app does to the running
/// desktop goes through here, so there is exactly one place that touches the shell.
public enum CommandRunner {
    public static func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        let printable = ([(executable as NSString).lastPathComponent] + arguments).joined(
            separator: " ")

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(
                        returning: CommandResult(
                            command: printable, status: -1, stdout: "",
                            stderr: error.localizedDescription))
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(
                    returning: CommandResult(
                        command: printable,
                        status: process.terminationStatus,
                        stdout: Self.clean(outData),
                        stderr: Self.clean(errData)))
            }
        }
    }

    private static func clean(_ data: Data) -> String {
        // String(decoding:) substitutes replacement characters rather than
        // failing. Daemon output is not guaranteed valid UTF-8, and losing a
        // whole error message to one bad byte would be worse than mangling it.
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
