import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Theme switcher page")
    struct SwitcherPageTests {
        @Test("the switcher lists, filters, navigates, applies and closes")
        func switcher() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "1-office.png", red: 0.1)
                try harness.addBackground(theme: "lumon", name: "2-hand-of-adam.png", red: 0.9)
                harness.model.themes.reload()
                let recorder = ThemeRecorder()
                let (switcher, surface) = try harness.switcherPage(recorder: recorder)
                try recorder.recordCloses(of: switcher)

                try await listsAndNavigates(harness, surface)
                try await filtersAndApplies(surface, recorder)
                try await actionsMenu(harness, surface, recorder)
                try await backgroundGrid(surface, recorder)
                try await switchBackgroundRow(harness, surface, recorder)
                try await escapeCloses(switcher, surface, recorder)

                #expect(recorder.applied == ["carbonfox"])
                #expect(recorder.backgrounds.count == 1)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        // The steps of `switcher()`, in order; each starts where the last ended.

        private func listsAndNavigates(_ harness: Harness, _ surface: WebSurface) async throws {
            try await waitFor(
                surface, "the theme list",
                """
                const titles = page.rows().map((row) => row.textContent);
                return titles.length === 9 && titles[0].startsWith("Switch Background")
                  && titles[1].startsWith("Awakening") && titles[2].startsWith("Lumon")
                  && page.activeRow()?.textContent.startsWith("Lumon");
                """)

            await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
            try await waitFor(
                surface, "focus in the search field and Lumon selected",
                #"return document.activeElement === page.search() && page.selectedRow()?.textContent.startsWith("Lumon");"#
            )

            try await run(surface, #"page.key(page.search(), "ArrowDown");"#)
            try await waitFor(
                surface, "Blackgold selected",
                #"return page.selectedRow()?.textContent.startsWith("Blackgold");"#)
            try await run(surface, #"page.key(page.search(), "ArrowUp");"#)
            try await waitFor(
                surface, "Lumon selected again",
                #"return page.selectedRow()?.textContent.startsWith("Lumon");"#)
        }

        private func filtersAndApplies(
            _ surface: WebSurface, _ recorder: ThemeRecorder
        )
            async throws
        {
            try await run(surface, #"page.setValue(page.search(), "carbon");"#)
            try await waitFor(
                surface, "only Carbonfox listed",
                #"return page.rows().length === 1 && page.selectedRow()?.textContent.startsWith("Carbonfox");"#
            )
            try await run(surface, #"page.key(page.search(), "Enter");"#)
            try await waitUntil("the recorder to apply carbonfox") {
                recorder.applied == ["carbonfox"]
            }
        }

        private func actionsMenu(
            _ harness: Harness, _ surface: WebSurface, _ recorder: ThemeRecorder
        ) async throws {
            await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
            try await waitFor(
                surface, "a fresh list",
                #"return page.search().value === "" && page.rows().length === 9;"#)
            try await run(surface, #"page.key(page.search(), "k", { metaKey: true });"#)
            try await waitFor(
                surface, "the actions menu",
                #"const menu = document.querySelector('[role=listbox][aria-label="Actions"]'); return !!menu && menu.innerText.includes("Switch Background");"#
            )
            try await run(surface, #"page.key(page.search(), "Escape");"#)
            try await waitFor(
                surface, "the actions menu closed",
                #"return !document.querySelector('[role=listbox][aria-label="Actions"]') && page.rows().length === 9;"#
            )
            #expect(
                recorder.closeRequests == 0, "Escape with the menu open must only close the menu")
        }

        /// The background grid from ⌘B on the selected theme.
        private func backgroundGrid(_ surface: WebSurface, _ recorder: ThemeRecorder) async throws {
            try await run(surface, #"page.key(page.search(), "b", { metaKey: true });"#)
            try await waitFor(
                surface, "the Lumon backgrounds with a loaded thumbnail",
                """
                const grid = document.querySelector('[role=listbox][aria-label="Backgrounds in Lumon"]');
                const images = [...(grid?.querySelectorAll("img") ?? [])];
                return images.length === 2
                  && images.every((img) => img.src.startsWith("macarchy-app://media/theme/lumon/"))
                  && images.some((img) => img.complete && img.naturalWidth > 0);
                """)
            try await run(surface, #"page.key(page.search(), "ArrowRight");"#)
            try await waitFor(
                surface, "the second tile selected",
                #"return document.querySelector('[role=option][aria-selected=true]')?.getAttribute("aria-label") === "Hand Of Adam";"#
            )
            try await run(surface, #"page.key(page.search(), "Enter");"#)
            try await waitUntil("the recorder to use the background") {
                recorder.backgrounds.count == 1
            }
            #expect(recorder.backgrounds.first?.theme == "lumon")
            #expect(recorder.backgrounds.first?.path == "backgrounds/2-hand-of-adam.png")
        }

        /// The Switch Background row opens the active theme's grid; Escape leaves it.
        private func switchBackgroundRow(
            _ harness: Harness, _ surface: WebSurface, _ recorder: ThemeRecorder
        ) async throws {
            await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
            try await run(
                surface,
                """
                page.key(page.search(), "ArrowUp");
                page.key(page.search(), "ArrowUp");
                """)
            try await waitFor(
                surface, "the Switch Background row selected",
                #"return page.selectedRow()?.textContent.startsWith("Switch Background");"#)
            try await run(surface, #"page.key(page.search(), "Enter");"#)
            try await waitFor(
                surface, "the grid from the row",
                #"return !!document.querySelector('[role=listbox][aria-label="Backgrounds in Lumon"]');"#
            )
            try await run(surface, #"page.key(page.search(), "Escape");"#)
            try await waitFor(surface, "the theme list again", "return page.rows().length === 9;")
            #expect(recorder.closeRequests == 0)
        }

        /// Escape at the top level asks the host to close; didClose resets.
        private func escapeCloses(
            _ switcher: ThemeSwitcher, _ surface: WebSurface, _ recorder: ThemeRecorder
        ) async throws {
            try await run(surface, #"page.setValue(page.search(), "mid");"#)
            try await waitFor(surface, "Midnight only", "return page.rows().length === 1;")
            try await run(surface, #"page.key(page.search(), "Escape");"#)
            try await waitUntil("the page to ask the host to close") { recorder.closeRequests == 1 }
            #expect(!switcher.isVisible)
            surface.send(.switcherDidClose)
            try await waitFor(
                surface, "the page reset after closing",
                #"return page.search().value === "" && page.rows().length === 9 && page.selectedRow()?.textContent.startsWith("Lumon");"#
            )
        }
    }
}
