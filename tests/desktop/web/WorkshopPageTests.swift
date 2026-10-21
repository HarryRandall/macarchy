import Foundation
import Testing

@testable import App
@testable import Macarchy

/// The Workshop page has drawn its views and the featured theme.
@MainActor
private func waitForWorkshop(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "the Workshop page",
        """
        return !!document.querySelector('[role=tablist][aria-label="Workshop views"]')
          && !!document.querySelector('button[aria-label="Try it on, Tokyo Night"]');
        """)
}

@MainActor
private func search(_ surface: WebSurface, _ query: String) async throws {
    try await run(
        surface,
        #"page.setValue(document.querySelector('input[aria-label="Search the Workshop"]'), "\#(query)");"#
    )
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Workshop page")
    struct WorkshopPageTests {
        @Test("installed themes are marked and the top-bar search filters, writing nothing")
        func installedAndSearch() async throws {
            try await withHarness { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .workshop)
                try await waitForWorkshop(surface)

                try await search(surface, "lumon")
                try await waitFor(
                    surface, "only Lumon, in use",
                    """
                    return !!document.querySelector('button[aria-label="Open Lumon, in use"]')
                      && !document.querySelector('button[aria-label="Try it on, Tokyo Night"]');
                    """)

                try await search(surface, "awakening")
                try await waitFor(
                    surface, "Awakening, installed",
                    #"return !!document.querySelector('button[aria-label="Open Awakening, installed"]');"#
                )

                try await search(surface, "no such design")
                try await waitFor(
                    surface, "the empty state",
                    #"return page.text().includes("Nothing matches");"#)
                try await run(
                    surface,
                    """
                    [...document.querySelectorAll("[data-slot=empty-state] button")]
                      .find((button) => button.textContent.trim() === "Clear search").click();
                    """)
                try await waitForWorkshop(surface)

                #expect(await harness.desktop.writes.isEmpty)
                #expect(harness.settingsData == before)
            }
        }

        @Test("trying a theme on and keeping it never changes the desktop")
        func tryingIsAPreview() async throws {
            try await withHarness { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .workshop)
                try await waitForWorkshop(surface)

                try await run(
                    surface,
                    #"document.querySelector('button[aria-label="Try it on, Tokyo Night"]').click();"#)
                try await waitFor(
                    surface, "the trying banner",
                    """
                    return [...document.querySelectorAll("[role=status]")]
                      .some((banner) => banner.innerText.includes("Trying Tokyo Night"));
                    """)
                try await run(
                    surface,
                    """
                    [...document.querySelectorAll("[role=status] button")]
                      .find((button) => button.textContent.trim() === "Keep it").click();
                    """)
                try await waitFor(
                    surface, "Tokyo Night in use on the page",
                    #"return document.querySelector('button[aria-label="In use, Tokyo Night"]')?.disabled === true;"#
                )

                // swiftlint:disable:next no_fixed_sleep_in_tests - proves keeping never applies; an absence has no signal to await.
                try await Task.sleep(for: .milliseconds(300))
                #expect(try harness.store.read().currentTheme == "lumon")
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("the details dialog pages with the arrow keys and closes with Escape")
        func detailsDialog() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage(pane: .workshop)
                try await waitForWorkshop(surface)

                try await search(surface, "nord")
                try await waitFor(
                    surface, "the Nord card",
                    #"return !!document.querySelector('button[aria-label="Open Nord"]');"#)
                try await run(surface, #"document.querySelector('button[aria-label="Open Nord"]').click();"#)
                try await waitFor(
                    surface, "the Nord dialog",
                    #"return document.querySelector("[role=dialog]")?.innerText.includes("1 of 3") === true;"#
                )

                try await run(surface, #"page.key(document.querySelector("[role=dialog]"), "ArrowRight");"#)
                try await waitFor(
                    surface, "the second picture",
                    #"return document.querySelector("[role=dialog]")?.innerText.includes("2 of 3") === true;"#
                )
                try await run(
                    surface,
                    """
                    const dialog = document.querySelector("[role=dialog]");
                    page.key(dialog, "ArrowLeft");
                    page.key(dialog, "ArrowLeft");
                    """)
                try await waitFor(
                    surface, "wrapped to the last picture",
                    #"return document.querySelector("[role=dialog]")?.innerText.includes("3 of 3") === true;"#
                )

                try await run(surface, #"page.key(document.querySelector("[role=dialog]"), "Escape");"#)
                // An offscreen window may never finish the exit transition, so a
                // closing dialog counts as closed.
                try await waitFor(
                    surface, "the dialog closed",
                    """
                    const dialog = document.querySelector("[role=dialog]");
                    return !dialog || dialog.hasAttribute("data-closed")
                      || dialog.hasAttribute("data-ending-style");
                    """)
            }
        }
    }
}
