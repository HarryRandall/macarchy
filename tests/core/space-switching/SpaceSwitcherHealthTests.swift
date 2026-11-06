import Testing

@testable import Macarchy

struct SpaceSwitcherHealthTests {
    @Test("while the app switches, Health says so and nothing more")
    func appSwitching() throws {
        let checks = SpaceSwitcher.healthChecks(appSwitching: true)
        let check = try #require(checks.first)
        #expect(checks.count == 1)
        #expect(check.title == "Instant Space switching")
        #expect(check.status == .passed)
        #expect(check.fix == nil)
    }

    @Test("without the app switching, Health says where to allow it")
    func notSwitching() throws {
        let check = try #require(
            SpaceSwitcher.healthChecks(appSwitching: false).first)
        #expect(check.status == .unknown)
        #expect(check.fix?.contains("Accessibility") == true)
    }
}
