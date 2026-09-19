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
}
