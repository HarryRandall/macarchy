import Testing

@testable import Macarchy

struct SpaceSwitcherHealthTests {
    @Test("while the app switches, Health says so and nothing more")
    func appSwitching() throws {
        let checks = SpaceSwitcher.healthChecks(appSwitching: true, oldSwitcherRunning: false)
        let check = try #require(checks.first)
        #expect(checks.count == 1)
        #expect(check.title == "Instant Space switching")
        #expect(check.status == .passed)
        #expect(check.fix == nil)
    }

    @Test("without the app switching, Health says where to allow it")
    func notSwitching() throws {
        let check = try #require(
            SpaceSwitcher.healthChecks(appSwitching: false, oldSwitcherRunning: false).first)
        #expect(check.status == .unknown)
        #expect(check.fix?.contains("Accessibility") == true)
    }

    @Test("InstantSpaceSwitcher still running is a warning with a way to remove it")
    func oldSwitcherRunning() throws {
        let checks = SpaceSwitcher.healthChecks(appSwitching: true, oldSwitcherRunning: true)
        #expect(checks.count == 2)
        let old = try #require(checks.last)
        #expect(old.title == "InstantSpaceSwitcher")
        #expect(old.status == .warning)
        #expect(old.command == "brew uninstall --cask jurplel/tap/instant-space-switcher")
    }

    @Test("setup no longer offers InstantSpaceSwitcher")
    func setupOffersNothing() {
        #expect(Setup.extras.isEmpty)
    }
}
