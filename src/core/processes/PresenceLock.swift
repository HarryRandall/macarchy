import Darwin
import Foundation

/// A lock a process holds on a file for as long as it does a job, so others
/// can see the job is being done. The lock goes with the process, however
/// it ends.
public enum PresenceLock {
    /// Takes the lock and returns its descriptor, to keep open for as long
    /// as the job runs. Nil before setup, so launching never creates
    /// Macarchy's folder, or when another process already holds it.
    public static func hold(at url: URL) -> Int32? {
        let root = url.deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.path),
            (try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)) != nil
        else { return nil }
        let descriptor = open(url.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return descriptor
    }

    /// Whether a process holds the lock now. Never creates the file: with no
    /// lock file, nothing has held it.
    public static func isHeld(at url: URL) -> Bool {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_SH | LOCK_NB) == 0 else { return errno == EWOULDBLOCK }
        flock(descriptor, LOCK_UN)
        return false
    }
}
