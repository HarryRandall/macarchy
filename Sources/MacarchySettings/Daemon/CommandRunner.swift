import Foundation

struct CommandResult: Sendable {
    let command: String
    let status: Int32
    let stdout: String
    let stderr: String

    var ok: Bool { status == 0 }

    /// What the console strip shows: stdout when it succeeded, stderr when it didn't.
    var summary: String { ok ? stdout : stderr }
}

/// Thin async wrapper over `Process`. Everything the app does to the running
/// desktop goes through here, so there is exactly one place that touches the shell.
enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        let printable = ([(executable as NSString).lastPathComponent] + arguments).joined(separator: " ")

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
                    continuation.resume(returning: CommandResult(
                        command: printable, status: -1, stdout: "",
                        stderr: error.localizedDescription))
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(returning: CommandResult(
                    command: printable,
                    status: process.terminationStatus,
                    stdout: Self.clean(outData),
                    stderr: Self.clean(errData)))
            }
        }
    }

    private static func clean(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
