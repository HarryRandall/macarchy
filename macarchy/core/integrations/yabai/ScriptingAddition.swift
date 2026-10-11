import CryptoKit
import Foundation

/// Whether yabai is still permitted to load its scripting addition.
///
/// Switching desktops is the one thing yabai cannot do through the public APIs,
/// so it loads a scripting addition into Dock.app to do it. Loading needs root,
/// and `yabairc` gets that from a passwordless sudo rule which pins the SHA-256
/// of the yabai binary — an unpinned rule would hand a password-less root shell
/// to anyone who could replace that file.
///
/// Upgrading yabai changes the hash, so the rule stops matching. The failure is
/// silent in the worst way: `sudo` asks for a password, launchd has no terminal
/// to ask at, and the load fails at login with nothing on screen to say so.
/// Every other yabai feature keeps working — only desktop switching goes quiet.
/// Nothing here needs privileges; the sudoers file is world-readable by design.
public enum ScriptingAddition {
    public static let sudoersPath = "/etc/sudoers.d/yabai"
    public static let bundlePath = "/Library/ScriptingAdditions/yabai.osax"

    public enum Status: Equatable, Sendable {
        /// The rule matches the binary on disk, so the load can succeed.
        case permitted
        /// yabai is not installed where the rest of the app expects it.
        case binaryMissing
        /// The addition itself was never installed (`yabai --install-sa`).
        case bundleMissing
        /// No sudo rule at all, so the load asks for a password and gives up.
        case ruleMissing
        /// The usual one: yabai was upgraded and the pinned hash went stale.
        case hashStale(pinned: String, actual: String)

        public var isPermitted: Bool { self == .permitted }

        /// Phrased for the person using the desktop, not the person who built it.
        public var explanation: String {
            switch self {
            case .permitted:
                "Desktop switching has the permission it needs."
            case .binaryMissing:
                "The window manager is not installed at \(Paths.yabai)."
            case .bundleMissing:
                "The desktop-switching helper is not installed. Run "
                    + "`sudo yabai --install-sa` to put it in place."
            case .ruleMissing:
                "The helper has no permission to load, so switching desktops "
                    + "does nothing. Repairing grants it again."
            case .hashStale:
                "The window manager was updated, so the helper that switches "
                    + "desktops lost permission to load. Every other window "
                    + "feature keeps working, which is why this is easy to miss."
            }
        }
    }

    /// Reads the state of the rule. No side effects, no privileges.
    public static func status(
        binary: String = Paths.yabai,
        sudoers: String = sudoersPath,
        bundle: String = bundlePath
    ) -> Status {
        guard let actual = digest(ofFileAt: binary) else { return .binaryMissing }
        guard FileManager.default.fileExists(atPath: bundle) else { return .bundleMissing }
        guard let rules = try? String(contentsOfFile: sudoers, encoding: .utf8),
            let pinned = pinnedDigest(in: rules, binary: binary)
        else { return .ruleMissing }
        return pinned == actual ? .permitted : .hashStale(pinned: pinned, actual: actual)
    }

    /// The lowercase hex SHA-256 of a file, which is the form sudo writes.
    public static func digest(ofFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        // The binary is a couple of megabytes; read it in chunks rather than
        // holding the whole thing to hash it.
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Pulls the hash out of the `--load-sa` line, ignoring any other rule in
    /// the file. sudo also accepts base64 digests; this only writes and reads
    /// hex, and treats anything else as no rule rather than guessing at it.
    static func pinnedDigest(in rules: String, binary: String) -> String? {
        for line in rules.split(separator: "\n") {
            guard line.contains(binary), line.contains("--load-sa"),
                let marker = line.range(of: "sha256:")
            else { continue }
            let hash = line[marker.upperBound...].prefix { $0.isHexDigit }
            guard hash.count == 64 else { continue }
            return hash.lowercased()
        }
        return nil
    }

    // MARK: - Repair

    /// The script the repair runs as root. Every value in it is generated here
    /// and checked against a fixed alphabet first, so nothing a person typed
    /// can reach the shell. `visudo -c` parses the new rule before it is
    /// installed: a sudoers file this app could not parse must never become the
    /// one sudo cannot parse either, because that locks the user out of sudo.
    static func repairScript(user: String, digest: String, binary: String = Paths.yabai) -> String?
    {
        guard user.allSatisfy({ $0.isLetter || $0.isNumber || "._-".contains($0) }), !user.isEmpty,
            digest.count == 64, digest.allSatisfy(\.isHexDigit)
        else { return nil }
        return """
            set -eu
            tmp=$(/usr/bin/mktemp)
            trap 'rm -f "$tmp"' EXIT
            printf '%s\\n' '\(user) ALL=(root) NOPASSWD: sha256:\(digest) \(binary) --load-sa' > "$tmp"
            /usr/sbin/visudo -cf "$tmp"
            /usr/bin/install -m 0644 -o root -g wheel "$tmp" \(sudoersPath)
            \(binary) --load-sa
            """
    }

    /// Re-pins the rule to the installed binary and loads the addition, behind
    /// the system's own password prompt. Loading is enough on its own — it is
    /// what `yabairc` does whenever the Dock restarts — so the window manager
    /// keeps running and the desktop is not rearranged.
    public static func repair(
        user: String = NSUserName(),
        binary: String = Paths.yabai,
        execute: @Sendable (String, [String]) async -> CommandResult = {
            // The prompt waits on a person, so it outlives the usual budget.
            await CommandRunner.run($0, $1, timeout: 300)
        }
    ) async -> CommandResult {
        let failed = { (message: String) in
            CommandResult(command: "repair scripting addition", status: 1, stderr: message)
        }
        guard let digest = digest(ofFileAt: binary) else {
            return failed("No window manager is installed at \(binary).")
        }
        guard let script = repairScript(user: user, digest: digest, binary: binary) else {
            return failed("Could not build the permission rule for “\(user)”.")
        }
        let result = await execute("/usr/bin/osascript", ["-e", appleScript(running: script)])
        guard result.ok else {
            // Cancelling the password prompt is a choice, not a fault.
            let cancelled = result.stderr.contains("-128")
            return failed(
                cancelled
                    ? "Repair cancelled."
                    : (result.stderr.isEmpty ? "Repair failed." : result.stderr)
            )
        }
        return CommandResult(
            command: "repair scripting addition", status: 0,
            stdout: "Desktop switching repaired.")
    }

    /// Wraps the script for `osascript`, which is handed the AppleScript as an
    /// argument rather than through a shell, so only AppleScript's own string
    /// escaping applies.
    static func appleScript(running script: String) -> String {
        let quoted =
            script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(quoted)\" with administrator privileges"
    }
}
