import Foundation
import Testing

@testable import App
@testable import Macarchy

/// The Menu Bar page has drawn its preview and zones.
@MainActor
private func waitForMenuBar(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "the Menu Bar page",
        """
        return page.text().includes("Changes here are a preview")
          && !!document.querySelector('[role=group][aria-label="Menu bar preview"]')
          && !!document.querySelector('button[aria-label="Move Battery"]');
        """)
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Menu Bar page")
    struct MenuBarPageTests {
        @Test("the page is drawn here, with the editor in the top bar")
        func drawnInReact() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitForMenuBar(surface)
                try await waitFor(
                    surface, "Open the editor in the top bar",
                    """
                    return [...document.querySelectorAll("[data-slot=top-bar-actions] button")]
                      .some((button) => button.textContent.trim() === "Open the editor");
                    """)
            }
        }

        @Test("editing the draft stays on the page and never writes")
        func editsStayLocal() async throws {
            try await withHarness { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitForMenuBar(surface)

                try await run(
                    surface,
                    #"page.key(document.querySelector('button[aria-label="Move CPU"]'), "ArrowLeft");"#
                )
                try await waitFor(
                    surface, "the keyboard move announced",
                    """
                    return [...document.querySelectorAll("[aria-live=polite]")]
                      .some((region) => region.textContent === "CPU, Left zone, 2 of 2");
                    """)

                try await run(surface, #"page.toggle("Centre zone").click();"#)
                try await waitFor(
                    surface, "the centre zone",
                    #"return [...document.querySelectorAll("h3")].some((heading) => heading.textContent === "Centre");"#
                )

                try await run(
                    surface,
                    #"document.querySelector('button[aria-label="Remove Battery"]').click();"#)
                try await waitFor(
                    surface, "Battery removed",
                    #"return !document.querySelector('button[aria-label="Move Battery"]');"#)

                try await run(
                    surface,
                    """
                    [...document.querySelectorAll("button")]
                      .find((button) => button.textContent.trim() === "Reset").click();
                    """)
                try await waitFor(
                    surface, "the draft reset",
                    """
                    return !!document.querySelector('button[aria-label="Move Battery"]')
                      && page.toggle("Centre zone").getAttribute("aria-checked") === "false";
                    """)

                // swiftlint:disable:next no_fixed_sleep_in_tests - proves editing never writes; an absence has no signal to await.
                try await Task.sleep(for: .milliseconds(300))
                #expect(await harness.desktop.writes.isEmpty)
                #expect(harness.settingsData == before)
            }
        }
    }
}
