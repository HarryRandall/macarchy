import Foundation
import Testing

@testable import App
@testable import Macarchy

/// The Layout page has rendered the daemon's values.
@MainActor
func waitForLayout(_ surface: WebSurface, gap: Int) async throws {
    try await waitFor(
        surface, "the Layout page with a window gap of \(gap)",
        """
        return page.text().includes("Give every window a place.")
          && page.number("Between windows")?.value === "\(gap)"
          && page.range("Between windows")?.value === "\(gap)";
        """)
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Layout page")
    struct LayoutPageTests {
        @Test("opening the page and refreshing it never write to yabai or settings")
        func openingIsReadOnly() async throws {
            try await withHarness { harness in
                await harness.desktop.set("window_gap", "14")
                let before = harness.settingsData

                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 14)
                // swiftlint:disable:next no_fixed_sleep_in_tests - proves opening never writes; an absence has no signal to await.
                try await Task.sleep(for: .milliseconds(500))

                #expect(await harness.desktop.writes.isEmpty)
                #expect(harness.settingsData == before)
                #expect(await !harness.desktop.calls.isEmpty, "the page never read the fake")

                await harness.desktop.set("window_gap", "18")
                let snapshot = try await harness.model.yabaiLayout.read()
                surface.send(.layoutChanged(harness.model.layoutState(snapshot)))
                try await waitForLayout(surface, gap: 18)
                // swiftlint:disable:next no_fixed_sleep_in_tests - proves a refresh never writes; an absence has no signal to await.
                try await Task.sleep(for: .milliseconds(500))

                #expect(await harness.desktop.writes.isEmpty)
                #expect(harness.settingsData == before)
            }
        }

        @Test("editing the gap applies to yabai, then saves, coalescing a drag")
        func editingAppliesThenSaves() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 8)

                try await run(
                    surface,
                    """
                    const slider = page.range("Between windows");
                    for (const value of [15, 16, 17, 20]) page.setValue(slider, value);
                    """)
                try await waitUntil("yabai to receive window_gap 20") {
                    await harness.desktop.writes.contains(["window_gap", "20"])
                }
                try await waitUntil("settings.json to record the gap") {
                    (try? harness.store.read().flatValues["YABAI_WINDOW_GAP"]) == "20"
                }
                // Let any straggling debounce fire before counting.
                // swiftlint:disable:next no_fixed_sleep_in_tests - counts writes that may never come; outlasts the page's debounce.
                try await Task.sleep(for: .milliseconds(300))

                let gapWrites = await harness.desktop.writes.filter { $0[0] == "window_gap" }
                #expect(
                    (1...2).contains(gapWrites.count),
                    "expected the drag to coalesce: \(gapWrites)")
                #expect(gapWrites.last == ["window_gap", "20"])
                #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "20")
                try await waitForLayout(surface, gap: 20)
            }
        }

        @Test("linked margins write every edge; unlinked, only the top")
        func linkedPadding() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 8)
                try await waitFor(
                    surface, "linked margins",
                    #"return page.toggle("Match all screen edges").getAttribute("aria-checked") === "true" && !!page.range("Screen margins");"#
                )

                try await run(surface, #"page.setValue(page.range("Screen margins"), 12);"#)
                try await waitUntil("all four edges at 12") {
                    let writes = await harness.desktop.writes
                    return ["top_padding", "bottom_padding", "left_padding", "right_padding"]
                        .allSatisfy { writes.contains([$0, "12"]) }
                }

                try await run(surface, #"page.toggle("Match all screen edges").click();"#)
                try await waitFor(
                    surface, "the top margin control",
                    #"return page.toggle("Match all screen edges").getAttribute("aria-checked") === "false" && !!page.range("Top margin");"#
                )
                try await run(surface, #"page.setValue(page.range("Top margin"), 20);"#)
                try await waitUntil("the top edge at 20") {
                    await harness.desktop.writes.contains(["top_padding", "20"])
                }
                // swiftlint:disable:next no_fixed_sleep_in_tests - proves the other edges are not written; outlasts the page's debounce.
                try await Task.sleep(for: .milliseconds(300))

                let atTwenty = await harness.desktop.writes.filter { $0[1] == "20" }.map { $0[0] }
                #expect(atTwenty == ["top_padding"])
                #expect(try harness.store.read().flatValues["YABAI_TOP_PADDING"] == "20")
                #expect(try harness.store.read().flatValues["YABAI_LEFT_PADDING"] == "12")
            }
        }

        @Test("choosing Stack writes the layout and disables the tiling controls")
        func choosingStack() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 8)
                try await waitFor(
                    surface, "tiling controls enabled",
                    #"return !page.disabled(page.select("Split direction")) && !page.disabled(page.toggle("Balance window sizes"));"#
                )

                try await run(surface, #"page.card("Stack").click();"#)
                try await waitUntil("yabai to receive layout stack") {
                    await harness.desktop.writes.contains(["layout", "stack"])
                }
                try await waitFor(
                    surface, "Stack selected and the arrangement controls disabled",
                    """
                    return page.card("Stack").getAttribute("aria-pressed") === "true"
                      && page.card("Tile").getAttribute("aria-pressed") === "false"
                      && page.disabled(page.select("Split direction"))
                      && page.disabled(page.select("New windows"))
                      && page.disabled(page.toggle("Balance window sizes"));
                    """)
                try await waitUntil("settings.json to record the layout") {
                    (try? harness.store.read().flatValues["YABAI_LAYOUT"]) == "stack"
                }
            }
        }

        @Test("a refused edit shows yabai's message and puts the slider back")
        func refusedEdit() async throws {
            try await withHarness { harness in
                await harness.desktop.set("window_gap", "14")
                await harness.desktop.reject("window_gap", message: "invalid value for window_gap")
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage()
                try await waitForLayout(surface, gap: 14)

                try await run(surface, #"page.setValue(page.range("Between windows"), 25);"#)
                try await waitFor(
                    surface, "the apply error",
                    """
                    return [...document.querySelectorAll("[role=alert]")].some((alert) =>
                      alert.innerText.includes("Could not apply that change")
                      && alert.innerText.includes("invalid value for window_gap"));
                    """)
                try await waitForLayout(surface, gap: 14)

                #expect(await harness.desktop.writes == [["window_gap", "25"]])
                #expect(await harness.desktop.config["window_gap"] == "14")
                #expect(harness.settingsData == before)
            }
        }

        @Test("with yabai unreachable the page shows saved values, read-only")
        func yabaiUnreachable() async throws {
            try await withHarness(settings: ["YABAI_WINDOW_GAP": "20", "YABAI_LAYOUT": "stack"]) {
                harness in
                await harness.desktop.stop()
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage()

                try await waitForLayout(surface, gap: 20)
                try await waitFor(
                    surface, "the saved-layout notice and disabled controls",
                    """
                    const notice = [...document.querySelectorAll("[role=status]")]
                      .find((element) => element.innerText.includes("Showing your saved layout"));
                    return !!notice && notice.innerText.includes("yabai isn't responding")
                      && page.card("Stack").getAttribute("aria-pressed") === "true"
                      && page.range("Between windows").disabled
                      && page.number("Between windows").disabled
                      && page.card("Tile").disabled
                      && page.disabled(page.toggle("Match all screen edges"))
                      && page.disabled(page.select("Modifier key"));
                    """)

                try await run(
                    surface,
                    """
                    page.setValue(page.range("Between windows"), 4);
                    page.card("Tile").click();
                    """)
                // swiftlint:disable:next no_fixed_sleep_in_tests - proves disabled controls never write; outlasts the page's debounce.
                try await Task.sleep(for: .milliseconds(400))

                #expect(await harness.desktop.writes.isEmpty)
                #expect(harness.settingsData == before)
                try await waitForLayout(surface, gap: 20)
            }
        }
    }
}
