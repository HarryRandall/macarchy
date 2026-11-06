import Foundation
import Darwin

/// Serialises desktop changes across the app and CLI without blocking the UI thread.
public enum OperationLock {
    public static func run<Value: Sendable>(
        root: URL = Paths.appRoot,
        operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let descriptor = open(root.appending(path: "desktop.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw ConfigurationError("Cannot open desktop lock") }
        defer { close(descriptor) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, ContinuousClock.now < deadline else {
                throw ConfigurationError("Desktop is busy; retry the change")
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        defer { flock(descriptor, LOCK_UN) }
        try Task.checkCancellation()
        return try await operation()
    }

    private struct Request<Outcome: Codable>: Codable {
        var id: String
        var value: String
        var outcome: Outcome?
    }

    /// Runs the newest of a burst of requests that replace each other, such as
    /// theme choices made while an earlier one is still applying.
    ///
    /// The lock is not first come, first served: waiters poll, so whichever
    /// polls first after a release takes it, and an older choice could run
    /// last and stick. So each request records itself before waiting, and
    /// whoever holds the lock next runs the newest recorded value and keeps
    /// its outcome. A request a newer one has already served returns that
    /// outcome instead of running. The record is a file, so requests from the
    /// app and the CLI replace each other too.
    public static func runLatest<Outcome: Codable & Sendable>(
        _ value: String, kind: String, root: URL = Paths.appRoot,
        operation: @Sendable (String) async throws -> Outcome
    ) async throws -> Outcome {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: "\(kind).request")
        let id = UUID().uuidString
        try FileLock.withLock(url) {
            try JSONEncoder().encode(Request<Outcome>(id: id, value: value))
                .write(to: url, options: .atomic)
        }
        return try await run(root: root) {
            // Only another process removing or corrupting the record makes it
            // unreadable; this request then simply runs.
            let pending = try FileLock.withLock(url) {
                try? JSONDecoder().decode(Request<Outcome>.self, from: Data(contentsOf: url))
            }
            guard let pending else { return try await operation(value) }
            if let outcome = pending.outcome { return outcome }
            let outcome = try await operation(pending.value)
            // A newer request recorded meanwhile is left for its own waiter.
            try FileLock.withLock(url) {
                let current = try? JSONDecoder().decode(
                    Request<Outcome>.self, from: Data(contentsOf: url))
                guard current?.id == pending.id else { return }
                var served = pending
                served.outcome = outcome
                try JSONEncoder().encode(served).write(to: url, options: .atomic)
            }
            return outcome
        }
    }
}
