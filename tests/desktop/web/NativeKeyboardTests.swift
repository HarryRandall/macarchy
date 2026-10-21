import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

// Keys sent as real `NSEvent`s through AppKit; `WebTestSupport+Keyboard.swift`
// explains how they reach a window that is never ordered in.

extension WebInterfaceTests {
    @MainActor
    @Suite("Native keyboard input")
    struct NativeKeyboardTests {
        @Test("Tab moves through the settings page in reading order, showing where focus is")
        func tabOrder() async throws {
            try await withHarness { harness in
                let (window, surface) = try offscreenSettings(harness)
                try await waitForLayout(surface, gap: 8)
                try await recordFocusBaseline(surface)

                // ⌥Tab reaches every control whatever the person's Keyboard
                // Navigation setting; plain Tab follows that setting.
                let all = try await tabCycle(Key.tab.with(.option), in: window, surface)
                let labels = all.map(\.label)
                for stop in all {
                    #expect(stop.focusVisible, "\(stop) is focused but not :focus-visible")
                    #expect(stop.shown, "\(stop) looks the same focused as at rest")
                }

                let sidebar = ["Home", "Themes", "Layout", "Shortcuts", "Advanced"]
                let page = [
                    "Split direction", "New windows", "Balance window sizes", "Between windows",
                    "Between windows in pt", "Match all screen edges", "Screen margins",
                    "Screen margins in pt", "Modifier key", "Move pointer to focused window",
                    "Drop action"
                ]
                let positions = (sidebar + page).map { labels.firstIndex(of: $0) }
                #expect(!positions.contains(nil), "missing stops in \(labels)")
                let found = positions.compactMap { $0 }
                #expect(found == found.sorted(), "out of order: \(labels)")
                #expect(
                    all.filter(\.main).map(\.label).prefix(3).allSatisfy { !page.contains($0) },
                    "the layout cards should come before the arrangement controls: \(labels)")
                #expect(
                    all.contains { $0.main && $0.tag == "INPUT" && $0.type == "range" },
                    "sliders should be reachable")

                // Focusing a control near the bottom scrolls the page, never
                // the shell around it, which would slide the sidebar and top
                // bar out of the window.
                let scrolled = string(
                    try await run(
                        surface,
                        """
                        return [document.scrollingElement, ...document.querySelectorAll("body *")]
                          .filter((element) => element && element.tagName !== "MAIN"
                            && (element.scrollTop > 0 || element.scrollLeft > 0))
                          .map((element) => element.tagName + "." + element.className).join("; ");
                        """))
                #expect(scrolled.isEmpty, "scrolled outside the page: \(scrolled)")

                // The toggle sits in the window's top-left corner, above the
                // sidebar, so it is the first stop.
                #expect(labels.first == "Collapse sidebar", "\(labels)")

                // Plain Tab visits a subset of the same stops, in the same order.
                let plain = try await tabCycle(.tab, in: window, surface).map(\.label)
                let plainPositions = plain.compactMap { labels.firstIndex(of: $0) }
                #expect(plainPositions.count == plain.count, "\(plain) not in \(labels)")
                #expect(plainPositions == plainPositions.sorted(), "\(plain)")
                for field in ["Between windows in pt", "Screen margins in pt", "Split direction"] {
                    #expect(plain.contains(field), "plain Tab skipped \(field): \(plain)")
                }
            }
        }

        @Test("arrow keys on the gap slider end in one debounced write")
        func sliderArrows() async throws {
            try await withHarness { harness in
                let (window, surface) = try offscreenSettings(harness)
                try await waitForLayout(surface, gap: 8)
                try await recordFocusBaseline(surface)

                try #require(
                    try await tabTo("Between windows", type: "range", in: window, surface),
                    "⌥Tab never reached the Between windows slider")

                // As a held key repeats.
                for _ in 0..<3 {
                    try press(.right, in: window)
                    try await Task.sleep(for: .milliseconds(30))
                }
                try press(.left, in: window)
                try await waitForLayout(surface, gap: 10)
                try await waitUntil("yabai to receive window_gap 10") {
                    await harness.desktop.writes.contains(["window_gap", "10"])
                }
                try await waitUntil("settings.json to record the gap") {
                    (try? harness.store.read().flatValues["YABAI_WINDOW_GAP"]) == "10"
                }
                try await Task.sleep(for: .milliseconds(300))

                #expect(await harness.desktop.writes == [["window_gap", "10"]])
                try await forgetLastFocus(surface)
                let focus = try await focused(surface)
                #expect(focus.label == "Between windows" && focus.focusVisible, "\(focus)")
            }
        }

        @Test("the switcher takes typing, arrows, Return and Escape from AppKit")
        func switcherKeys() async throws {
            try await withHarness { harness in
                let recorder = ThemeRecorder()
                let offscreen = try OffscreenSwitcher(harness, recorder: recorder)
                let (panel, surface) = (offscreen.panel, offscreen.surface)
                try recorder.recordCloses(of: offscreen.switcher)
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")
                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                try await waitFor(
                    surface, "focus in the search field",
                    #"return document.activeElement === page.search() && page.selectedRow()?.textContent.startsWith("Lumon");"#
                )

                try press(.down, in: panel)
                try await waitFor(
                    surface, "Blackgold selected",
                    #"return page.selectedRow()?.textContent.startsWith("Blackgold");"#)
                try press(.up, in: panel)
                try await waitFor(
                    surface, "Lumon selected",
                    #"return page.selectedRow()?.textContent.startsWith("Lumon");"#)

                try typeText("carb", in: panel)
                try await waitFor(
                    surface, "only Carbonfox listed",
                    #"return page.search().value === "carb" && page.rows().length === 1 && page.selectedRow()?.textContent.startsWith("Carbonfox");"#
                )

                // ⌘K opens the actions menu; the first Escape closes only that.
                try press(.command("k"), in: panel)
                try await waitFor(
                    surface, "the actions menu",
                    #"return !!document.querySelector('[role=listbox][aria-label="Actions"]');"#)
                try press(.escape, in: panel)
                try await waitFor(
                    surface, "the actions menu closed, the search kept",
                    #"return !document.querySelector('[role=listbox][aria-label="Actions"]') && page.search().value === "carb";"#
                )
                #expect(recorder.closeRequests == 0)

                try press(.enter, in: panel)
                try await waitUntil("the recorder to apply carbonfox") {
                    recorder.applied == ["carbonfox"]
                }

                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                try await waitFor(
                    surface, "a fresh list",
                    #"return page.search().value === "" && page.rows().length === 9;"#)
                try press(.escape, in: panel)
                try await waitUntil("Escape to ask the host to close") {
                    recorder.closeRequests == 1
                }
                #expect(recorder.applied == ["carbonfox"])
                #expect(!panel.isVisible)
            }
        }

        @Test("⌘K, ⌘B and ⌘R reach the switcher page before the main menu")
        func switcherCommandKeys() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "1-office.png", red: 0.1)
                harness.model.themes.reload()
                let recorder = ThemeRecorder()
                let menu = MenuRecorder()
                defer { menu.restore() }
                let offscreen = try OffscreenSwitcher(harness, recorder: recorder)
                let (panel, surface) = (offscreen.panel, offscreen.surface)
                var refreshes = 0
                surface.router.register("switcher.refresh") {
                    [weak model = harness.model] (_: Empty) in
                    refreshes += 1
                    guard let model else { throw BridgeFailure(.unavailable, "gone") }
                    return model.switcherState()
                }
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")
                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                try await waitFor(
                    surface, "Lumon selected",
                    #"return page.selectedRow()?.textContent.startsWith("Lumon");"#)

                try press(.command("k"), in: panel)
                try await waitFor(
                    surface, "the actions menu from ⌘K",
                    #"return !!document.querySelector('[role=listbox][aria-label="Actions"]');"#)
                #expect(menu.searches == 0, "⌘K reached the main menu's Search… as well")
                try press(.command("k"), in: panel)
                try await waitFor(
                    surface, "the actions menu closed by ⌘K",
                    #"return !document.querySelector('[role=listbox][aria-label="Actions"]');"#)

                try press(.command("b"), in: panel)
                try await waitFor(
                    surface, "the Lumon backgrounds from ⌘B",
                    #"return !!document.querySelector('[role=listbox][aria-label="Backgrounds in Lumon"]');"#
                )
                try press(.escape, in: panel)
                try await waitFor(
                    surface, "the theme list again", "return page.rows().length === 9;")

                try press(.command("r"), in: panel)
                try await waitUntil("⌘R to refresh through the bridge") { refreshes == 1 }

                // Typed text must not have picked up the letters.
                let typed = string(try await run(surface, "return page.search().value"))
                #expect(typed.isEmpty, "the search field took \(typed)")
                #expect(menu.searches == 0)
                #expect(recorder.applied.isEmpty && recorder.backgrounds.isEmpty)
            }
        }

        @Test("⌘V is left to the Edit menu's Paste")
        func switcherPaste() async throws {
            // WebKit pastes from the general pasteboard in the app process,
            // with no public way to give a web view another one, so the text
            // itself is not pasted here. This checks the part the app owns:
            // the page lets ⌘V through and it reaches Paste, which in the app
            // goes to the first responder, the web view.
            try await withHarness { harness in
                let recorder = ThemeRecorder()
                let menu = MenuRecorder()
                defer { menu.restore() }
                let offscreen = try OffscreenSwitcher(harness, recorder: recorder)
                let (panel, surface) = (offscreen.panel, offscreen.surface)
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")
                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                try await waitFor(
                    surface, "focus in the search field",
                    "return document.activeElement === page.search();")

                try press(.command("v"), in: panel)
                try await waitUntil("⌘V to reach Paste") { menu.pastes == 1 }
                #expect(menu.searches == 0)
                let pasted = string(try await run(surface, "return page.search().value"))
                #expect(pasted.isEmpty, "the search field took \(pasted)")
            }
        }
    }
}
