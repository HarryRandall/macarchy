import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Home page")
    struct HomePageTests {
        @Test("real summary is read-only, previews are labelled and external state refreshes")
        func summary() async throws {
            try await withHarness { harness in
                try harness.write("ctrl - a : echo a\n", to: ".config/skhd/skhdrc")
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .home)
                try await waitFor(
                    surface, "Home summary",
                    """
                    return page.text().toLowerCase().includes("your desktop")
                      && page.text().includes("lumon")
                      && page.text().includes("Plugins (preview)")
                      && page.text().includes("Workshop (preview)")
                      && document.querySelectorAll('[data-slot="stat-tile"]').length === 4;
                    """)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
                await harness.desktop.set("layout", "stack")
                surface.send(.homeChanged)
                try await waitFor(
                    surface, "external layout summary", "return page.text().includes('Stacked');")
                try await run(
                    surface,
                    """
                    [...document.querySelectorAll('button')]
                      .find(button => button.getAttribute('aria-label')?.startsWith('Layout.')).click();
                    """)
                try await waitForLayout(surface, gap: 8)
                #expect(harness.settingsData == before)
            }
        }

        @Test("invalid saved settings show a retryable error")
        func readFailure() async throws {
            try await withHarness { harness in
                try Data("broken".utf8).write(to: harness.store.url)
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .home)
                try await waitFor(
                    surface, "summary error",
                    """
                    return !!document.querySelector('[role=alert]') && page.text().includes('Try again')
                      && !document.querySelector('[data-slot="hero-card"]');
                    """)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }
    }
}
