import Foundation
import Testing

/// Reset baselines come from the repository when the tests are unbundled.
struct ThemeResources: SuiteTrait, TestScoping {
    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        let previous = getenv("MACARCHY_RESOURCES").map { String(cString: $0) }
        setenv("MACARCHY_RESOURCES", repository.appending(path: "resources").path, 1)
        defer {
            if let previous {
                setenv("MACARCHY_RESOURCES", previous, 1)
            } else {
                unsetenv("MACARCHY_RESOURCES")
            }
        }
        try await function()
    }
}
