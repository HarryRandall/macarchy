import Foundation
import Synchronization
import Testing

@testable import Macarchy

@Suite("OperationLock")
struct OperationLockTests {
    private func sandbox() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-lock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw ConfigurationError("Timed out") }
            // swiftlint:disable:next no_fixed_sleep_in_tests - polls the request file, which has no change signal.
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    /// Waiters poll the lock, so which of two queued requests takes it first
    /// is arbitrary. Repeating covers both orders.
    @Test("the newest queued request wins, whichever waiter takes the lock")
    func latestRequestWins() async throws {
        for _ in 0..<6 {
            let root = try sandbox()
            defer { try? FileManager.default.removeItem(at: root) }
            let record = root.appending(path: "theme.request")
            let recorded = { (value: String) in
                ((try? String(contentsOf: record, encoding: .utf8)) ?? "")
                    .contains("\"value\":\"\(value)\"")
            }
            let ran = Mutex<[String]>([])
            let (started, start) = AsyncStream<Void>.makeStream()
            let (gate, open) = AsyncStream<Void>.makeStream()
            let operation: @Sendable (String) async throws -> String = { value in
                ran.withLock { $0.append(value) }
                if value == "A" {
                    start.finish()
                    for await _ in gate {}
                }
                return "applied \(value)"
            }
            func request(_ value: String) -> Task<String, Error> {
                Task {
                    try await OperationLock.runLatest(value, kind: "theme", root: root) {
                        try await operation($0)
                    }
                }
            }

            let first = request("A")
            for await _ in started {}
            let second = request("B")
            try await waitUntil { recorded("B") }
            let third = request("C")
            try await waitUntil { recorded("C") }
            open.finish()

            #expect(try await first.value == "applied A")
            #expect(try await second.value == "applied C")
            #expect(try await third.value == "applied C")
            #expect(ran.withLock { $0 } == ["A", "C"])
        }
    }

    @Test("a request runs its own value when nothing newer is waiting")
    func singleRequestRuns() async throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        for value in ["A", "B", "A"] {
            let result = try await OperationLock.runLatest(value, kind: "theme", root: root) {
                "applied \($0)"
            }
            #expect(result == "applied \(value)")
        }
    }
}
