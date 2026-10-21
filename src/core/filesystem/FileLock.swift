import Darwin
import Foundation

/// An exclusive lock on `<path>.lock` for short read-modify-write sections.
///
/// Waiting is bounded: another process holding the lock must surface as an
/// error, not freeze the caller, which is often the main thread.
enum FileLock {
    static func withLock<Value>(
        _ url: URL, timeout: Duration = .seconds(5), _ body: () throws -> Value
    ) throws -> Value {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            throw ConfigurationError("Cannot open lock for \(url.lastPathComponent)")
        }
        defer { close(descriptor) }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, ContinuousClock.now < deadline else {
                throw ConfigurationError("\(url.lastPathComponent) is busy; try again")
            }
            usleep(10_000)
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
