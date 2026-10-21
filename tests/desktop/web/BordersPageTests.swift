import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
private func openBorders(_ harness: Harness) async throws -> (SettingsWindow, WebSurface) {
    await harness.desktop.answer("defaults") { _ in .success() }
    // The exact missing-default reply must precede the general write responder.
    await harness.desktop.answer(
        "defaults", ["read", "-g", "NSConvolutionOverride1"],
        with: .failure("does not exist"))
    await harness.desktop.answer("launchctl") { _ in .success("state = running\npid = 42") }
    await harness.desktop.answer("borders") { _ in .success() }
    let (window, surface) = try harness.settingsPage(pane: .borders)
    surface.router.registerBorders(
        model: harness.model, pickApplication: { BordersApplication(name: "Messages", icon: nil) })
    try await waitFor(
        surface, "sidebar",
        #"return !!document.querySelector('button[data-pane-row][aria-label="Borders"]');"#)
    try await run(
        surface, #"document.querySelector('button[data-pane-row][aria-label="Borders"]').click();"#)
    try await waitFor(
        surface, "Borders",
        #"return page.text().includes("The outline drawn around the focused window.") && !!page.range("Width");"#
    )
    return (window, surface)
}

@MainActor
private func bordersButton(_ surface: WebSurface, _ title: String) async throws {
    try await run(
        surface,
        """
        [...document.querySelectorAll("button")].find(button => button.textContent.trim() === "\(title)").click();
        """)
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Borders page")
    struct BordersPageTests {
        @Test("opening and refreshing show isolated saved values and never write")
        func openingIsReadOnly() async throws {
            try await withHarness(settings: ["BORDER_WIDTH": "9"], tools: ["borders"]) { harness in
                let before = harness.settingsData
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                try await waitFor(
                    surface, "saved width", #"return page.range("Width").value === "9";"#)
                surface.send(.bordersChanged(try await harness.model.bordersState()))
                try await Task.sleep(for: .milliseconds(300))
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.calls(to: "borders").isEmpty)
                #expect(
                    await harness.desktop.calls(to: "defaults").allSatisfy { $0.first == "read" })
            }
        }

        @Test("manual geometry, corners, colours and exclusions apply together and reset as drafts")
        func editsApplyThenSave() async throws {
            try await withHarness(tools: ["borders"]) { harness in
                let before = harness.settingsData
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                try await run(surface, #"page.setValue(page.range("Width"), 10);"#)
                try await bordersButton(surface, "Square")
                try await bordersButton(surface, "Add Application…")
                try await waitFor(
                    surface, "picked app", #"return page.text().includes("Messages");"#)
                try await run(
                    surface,
                    #"document.querySelector('[data-slot="colour-well"][aria-label^="Active border colour"]').click();"#
                )
                try await waitFor(
                    surface, "colour editor",
                    #"return !!page.select("Active border colour hex value");"#)
                try await run(
                    surface,
                    #"""
                    const hex = page.select("Active border colour hex value");
                    page.setValue(hex, "0x80112233"); page.key(hex, "Enter"); hex.blur();
                    """#)
                // Close the picker using its normal keyboard dismissal.
                try await run(
                    surface, #"page.key(page.select("Active border colour hex value"), "Escape");"#)
                #expect(harness.settingsData == before)
                try await bordersButton(surface, "Apply")
                try await waitUntil("complete border appearance saved") {
                    let values = try? harness.store.read().flatValues
                    return values?["BORDER_WIDTH"] == "10" && values?["BORDER_RADIUS"] == "0.3"
                        && values?["BORDERS_BLACKLIST"]?.contains("Messages") == true
                }
                #expect(
                    try Theme.read(from: harness.themes.appending(path: "lumon")).colors
                        .borderActive == "0x80112233")
                #expect(
                    await harness.desktop.calls(to: "borders").last?.contains("width=10.0") == true)
                let saved = harness.settingsData
                try await bordersButton(surface, "Reset")
                try await bordersButton(surface, "Use default")
                try await bordersButton(surface, "Clear all")
                #expect(harness.settingsData == saved)
                try await bordersButton(surface, "Discard")
                try await waitFor(
                    surface, "discarded draft",
                    #"return page.range("Width").value === "10" && page.text().includes("Messages");"#
                )
            }
        }

        @Test("live edits coalesce and failures stay visible without saving")
        func liveAndFailure() async throws {
            try await withHarness(tools: ["borders"]) { harness in
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                try await run(
                    surface,
                    #"""
                    page.toggle("Live preview").click();
                    for (const width of [8, 9, 10, 11]) page.setValue(page.range("Width"), width);
                    """#)
                try await waitUntil("live edit saved") {
                    (try? harness.store.read().flatValues["BORDER_WIDTH"]) == "11"
                }
                try await Task.sleep(for: .milliseconds(300))
                #expect(await harness.desktop.calls(to: "borders").count == 1)
                let saved = harness.settingsData
                await harness.desktop.answer("borders") { _ in .failure("Border test rejection") }
                try await run(surface, #"page.toggle("Show borders").click();"#)
                try await waitFor(
                    surface, "visible failure",
                    #"return page.text().includes("Border test rejection") && page.text().includes("Retry Apply");"#
                )
                #expect(harness.settingsData == saved)
                try await waitFor(
                    surface, "live disabled",
                    #"return page.toggle("Live preview").getAttribute("aria-checked") === "false";"#
                )
            }
        }

        @Test("external settings and theme changes update idle pages and preserve unsaved drafts")
        func externalChanges() async throws {
            try await withHarness(tools: ["borders"]) { harness in
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                try harness.store.write(["BORDER_WIDTH": "12"])
                surface.send(.bordersChanged(try await harness.model.bordersState()))
                try await waitFor(
                    surface, "external width", #"return page.range("Width").value === "12";"#)
                try await run(surface, #"page.setValue(page.range("Width"), 10);"#)
                try harness.store.update { $0.currentTheme = "blackgold" }
                harness.model.themes.reload()
                surface.send(.themesChanged(harness.model.switcherState()))
                try await waitFor(
                    surface, "draft retained on theme change",
                    #"return page.range("Width").value === "10" && page.text().includes("Borders changed elsewhere");"#
                )
                try await bordersButton(surface, "Apply")
                try await waitFor(
                    surface, "stale theme refused",
                    #"return page.text().includes("active theme changed");"#)
                #expect(try harness.store.read().flatValues["BORDER_WIDTH"] == "12")
                try await bordersButton(surface, "Discard")
                try await waitFor(
                    surface, "latest theme loaded", #"return page.range("Width").value === "12";"#)
                #expect(await harness.desktop.calls(to: "borders").isEmpty)
            }
        }

        @Test("missing tool shows saved settings and a failed first read offers Try again")
        func unavailableAndReadFailure() async throws {
            try await withHarness(settings: ["BORDER_WIDTH": "9"], tools: []) { harness in
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                await harness.desktop.answer("launchctl") { _ in .failure("Not running") }
                surface.send(.bordersChanged(try await harness.model.bordersState()))
                try await waitFor(
                    surface, "missing borders",
                    #"return page.text().includes("isn't installed") && page.range("Width").disabled;"#
                )
                #expect(await harness.desktop.calls(to: "borders").isEmpty)
            }
            try await withHarness(tools: ["borders"]) { harness in
                let (window, surface) = try await openBorders(harness)
                defer { _ = window }
                // Register a failed read and reload the real page.
                await harness.desktop.answer("defaults") { _ in .failure("Corners unavailable") }
                surface.load()
                try await waitFor(
                    surface, "failed read",
                    #"return page.text().includes("Could not read your borders") && page.text().includes("Try again");"#
                )
                #expect(await harness.desktop.calls(to: "borders").isEmpty)
            }
        }
    }
}
