import Foundation

/// macOS turns Secure Keyboard Entry on for the whole login session whenever an
/// app focuses a password field, and the hotkey daemon refuses to start while
/// it is on: it could not see the keys it is meant to bind, so it aborts rather
/// than pretend to work.
///
/// This is the one failure the Advanced pane could not explain. `launchctl
/// kickstart` reports success — launchd really did spawn the process — and the
/// daemon is gone again before the next status read, so the console showed a
/// green line above a stopped service. The name of the app holding secure input
/// is the entire diagnosis, so it is read back rather than guessed at.
public struct SecureInput: Sendable, Equatable {
    /// The process that turned Secure Keyboard Entry on.
    public let pid: Int
    /// What to call that process when explaining the failure.
    public let owner: String

    public init(pid: Int, owner: String) {
        self.pid = pid
        self.owner = owner
    }

    /// True when this very process is the one in the way, which is the common
    /// case rather than the exotic one: the button that restarts the hotkey
    /// daemon lives in an app that is, by definition, frontmost when clicked.
    public var isThisProcess: Bool { pid == Int(ProcessInfo.processInfo.processIdentifier) }

    public var explanation: String {
        isThisProcess
            ? "Secure Keyboard Entry is on, held by this app."
            : "Secure Keyboard Entry is on, held by “\(owner)”."
    }
}

extension SecureInput {
    /// The current holder, or `nil` when secure input is off.
    ///
    /// `-n Root -d1` is the cheapest node carrying `IOConsoleUsers`; dumping the
    /// whole registry to find the same dictionary costs a hundred times as much.
    public static func current(execute: Integrations.Execute) async -> SecureInput? {
        let registry = await execute(Paths.ioreg, ["-n", "Root", "-d1", "-w", "0"])
        guard registry.ok, let pid = pid(inConsoleUsers: registry.stdout) else { return nil }
        let name = await execute(Paths.ps, ["-p", "\(pid)", "-o", "comm="])
        return SecureInput(
            pid: pid, owner: owner(fromCommand: name.ok ? name.stdout : "", pid: pid))
    }

    /// The key is absent entirely while secure input is off, and a zero is left
    /// behind instead of a removal often enough to matter. Both mean nobody.
    static func pid(inConsoleUsers registry: String) -> Int? {
        guard let match = registry.firstMatch(of: /"kCGSSessionSecureInputPID"\s*=\s*(\d+)/),
            let pid = Int(match.1), pid > 0
        else { return nil }
        return pid
    }

    /// `ps -o comm=` prints the executable's path; its last component is what
    /// people — and the daemon's own error message — call the app.
    static func owner(fromCommand output: String, pid: Int) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "process \(pid)" }
        return URL(fileURLWithPath: trimmed).lastPathComponent
    }
}
