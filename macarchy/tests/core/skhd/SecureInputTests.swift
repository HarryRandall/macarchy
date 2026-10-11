import Foundation
import Testing

@testable import Macarchy

/// The registry dumps here are trimmed from the real `ioreg -n Root -d1` on the
/// morning the hotkey daemon would not start: the settings app itself had been
/// handed Secure Keyboard Entry, so every restart clicked in its own Advanced
/// pane spawned an skhd that aborted before the next status read.
@Suite("SecureInput")
struct SecureInputTests {
    private static func consoleUsers(_ extra: String) -> String {
        """
          |   "IOConsoleUsers" = ({"kCGSSessionOnConsoleKey"=Yes,"kCGSSessionIDKey"=257,\
        "kCGSSessionUserNameKey"="alex"\(extra),"kCGSSessionUserIDKey"=501})
        """
    }

    @Test("reads the holder out of a real registry dump")
    func holder() {
        let dump = Self.consoleUsers(",\"kCGSSessionSecureInputPID\"=82230")
        #expect(SecureInput.pid(inConsoleUsers: dump) == 82230)
    }

    /// Secure input off is the common case, and macOS says so by leaving the
    /// key out altogether.
    @Test("an absent key means nobody is holding it")
    func absent() {
        #expect(SecureInput.pid(inConsoleUsers: Self.consoleUsers("")) == nil)
    }

    /// A zero is left behind instead of a removal often enough to matter, and
    /// reading it as a pid would blame process 0 for a session that is fine.
    @Test("a zero means nobody is holding it")
    func zero() {
        let dump = Self.consoleUsers(",\"kCGSSessionSecureInputPID\"=0")
        #expect(SecureInput.pid(inConsoleUsers: dump) == nil)
    }

    @Test("names the app rather than its path")
    func ownerName() {
        let path = "/Users/alex/Applications/Macarchy.app/Contents/MacOS/MacarchySettings\n"
        #expect(SecureInput.owner(fromCommand: path, pid: 82230) == "MacarchySettings")
    }

    /// A holder that has already quit leaves nothing for `ps` to print. The pid
    /// is still worth saying: it is what the daemon's own error message names.
    @Test("falls back to the pid when the process has gone")
    func ownerGone() {
        #expect(SecureInput.owner(fromCommand: "", pid: 82230) == "process 82230")
    }

    @Test("finds the job's error log in a launchctl description")
    func errorPath() {
        let description = """
            {
            \t"StandardOutPath" = "/tmp/skhd.out.log";
            \t"StandardErrorPath" = "/tmp/skhd.err.log";
            \t"Label" = "com.koekeishiya.skhd";
            \t"LastExitStatus" = 256;
            };
            """
        #expect(
            Integrations.standardErrorPath(inJobDescription: description) == "/tmp/skhd.err.log")
    }
}

/// `launchctl kickstart` exits 0 as soon as launchd has *spawned* a job, so
/// every one of these covers the gap between "launchd tried" and "it is
/// running".
@Suite("Daemon restart")
struct DaemonRestartTests {
    /// Records what was run so a restart that should never have been attempted
    /// can be proven not to have been.
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var commands: [[String]] = []
        var responses: [([String]) -> CommandResult?] = []

        func run(_ executable: String, _ arguments: [String]) -> CommandResult {
            lock.withLock { commands.append([executable] + arguments) }
            for response in responses {
                if let result = response([executable] + arguments) { return result }
            }
            return CommandResult(command: arguments.joined(separator: " "), status: 0)
        }

        var ran: [[String]] { lock.withLock { commands } }
        func used(_ needle: String) -> Bool { ran.contains { $0.contains(needle) } }
    }

    private static func secureInputOn(pid: Int) -> ([String]) -> CommandResult? {
        { arguments in
            if arguments.first == Paths.ioreg {
                return CommandResult(
                    command: "ioreg", status: 0,
                    stdout: "\"kCGSSessionSecureInputPID\"=\(pid)")
            }
            if arguments.first == Paths.ps {
                return CommandResult(command: "ps", status: 0, stdout: "/Applications/Firefox.app")
            }
            return nil
        }
    }

    /// The bug this exists for: the restart button fired a kickstart that could
    /// not possibly work, and the console reported it as a success.
    @Test("skhd is not kickstarted while secure input is on")
    func refusesBlockedStart() async {
        let recorder = Recorder()
        recorder.responses = [Self.secureInputOn(pid: 82230)]
        let integrations = Integrations { recorder.run($0, $1) }

        let result = await integrations.restart(.skhd, attempts: 1, settle: .zero)

        #expect(!result.ok)
        #expect(result.stderr.contains("Secure Keyboard Entry"))
        #expect(result.stderr.contains("Firefox"))
        #expect(!recorder.used("kickstart"))
    }

    /// Secure input only stops the hotkey daemon; the others are started even
    /// while someone is typing a password.
    @Test("the other daemons start regardless of secure input")
    func otherDaemonsIgnoreSecureInput() async {
        let recorder = Recorder()
        recorder.responses = [
            Self.secureInputOn(pid: 82230),
            { arguments in
                arguments.contains("print")
                    ? CommandResult(
                        command: "print", status: 0, stdout: "\tstate = running\n\tpid = 4242")
                    : nil
            }
        ]
        let integrations = Integrations { recorder.run($0, $1) }

        let result = await integrations.restart(.borders, attempts: 4, settle: .zero)

        #expect(result.ok)
        #expect(recorder.used("kickstart"))
    }

    /// A spawn that dies is a failure, and the reason is in the job's own log
    /// rather than anywhere launchd will tell you about.
    @Test("a daemon that does not stay running reports why")
    func reportsStartupFailure() async {
        let recorder = Recorder()
        recorder.responses = [
            { arguments in
                arguments.contains("list")
                    ? CommandResult(
                        command: "list", status: 0,
                        stdout: "\t\"StandardErrorPath\" = \"/tmp/skhd.err.log\";")
                    : nil
            },
            { arguments in
                arguments.first == Paths.tail
                    ? CommandResult(
                        command: "tail", status: 0,
                        stdout:
                            "skhd: secure keyboard entry is enabled by (48546) 'chatgpt'! abort..")
                    : nil
            },
            // `launchctl print` succeeding with no state line is a loaded job
            // that is not running — exactly what an aborted daemon looks like.
            { arguments in
                arguments.contains("print") ? CommandResult(command: "print", status: 0) : nil
            }
        ]
        let integrations = Integrations { recorder.run($0, $1) }

        let result = await integrations.restart(.skhd, attempts: 2, settle: .zero)

        #expect(!result.ok)
        #expect(result.stderr.contains("did not stay running"))
        #expect(result.stderr.contains("chatgpt"))
    }

    /// One running read is not a start: a daemon about to abort still answers
    /// for an instant after the spawn.
    @Test("a single running read is not treated as a successful start")
    func requiresTwoReads() async {
        let recorder = Recorder()
        let reads = Counter()
        recorder.responses = [
            { arguments in
                guard arguments.contains("print") else { return nil }
                return reads.next() == 0
                    ? CommandResult(
                        command: "print", status: 0, stdout: "\tstate = running\n\tpid = 4242")
                    : CommandResult(command: "print", status: 0)
            }
        ]
        let integrations = Integrations { recorder.run($0, $1) }

        let result = await integrations.restart(.borders, attempts: 3, settle: .zero)

        #expect(!result.ok)
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int {
            lock.withLock {
                defer { value += 1 }; return value
            }
        }
    }
}
