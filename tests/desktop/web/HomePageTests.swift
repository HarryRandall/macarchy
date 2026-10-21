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

        @Test("the file watch follows ~/.skhdrc and a symlinked skhdrc's target")
        func shortcutFileWatch() async throws {
            try await withHarness { harness in
                let fm = FileManager.default
                let watch = HomeFileWatch()
                try harness.write("ctrl - a : echo a\n", to: ".skhdrc")
                let dotfile = watch.fingerprint()
                try harness.write("ctrl - a : echo a\nctrl - b : echo b\n", to: ".skhdrc")
                #expect(watch.fingerprint() != dotfile)

                try harness.write("ctrl - c : echo c\n", to: "dotfiles/skhdrc")
                let unlinked = watch.fingerprint()
                let link = harness.home.appending(path: ".config/skhd/skhdrc")
                try fm.createDirectory(
                    at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.createSymbolicLink(
                    at: link, withDestinationURL: harness.home.appending(path: "dotfiles/skhdrc"))
                let linked = watch.fingerprint()
                #expect(linked != unlinked)
                try harness.write("ctrl - c : echo c\nctrl - d : echo d\n", to: "dotfiles/skhdrc")
                #expect(watch.fingerprint() != linked)
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
