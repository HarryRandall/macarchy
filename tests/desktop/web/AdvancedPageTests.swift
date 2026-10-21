import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
private func advancedPage(_ harness: Harness) throws -> WebSurface {
    try harness.settingsPage(pane: .advanced).1
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Advanced page")
    struct AdvancedPageTests {
        @Test("an invalid settings file shows Try again without rendering defaults")
        func unreadableSettings() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                try Data("broken JSON".utf8).write(to: harness.store.url)
                let before = harness.settingsData
                let surface = try advancedPage(harness)
                try await waitFor(
                    surface, "read error",
                    #"return page.text().includes("Could not read Advanced settings") && page.text().includes("Try again") && !page.text().includes("Desktop services");"#
                )
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test(
            "opening and refreshing read the isolated state without writes; external state updates")
        func readOnlyAndExternal() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                let before = harness.settingsData
                let surface = try advancedPage(harness)
                let broadcast = StateBroadcast(settings: { surface }, switcher: { nil })
                broadcast.start(harness.model)
                defer { withExtendedLifetime(broadcast) {} }
                try await waitFor(
                    surface, "Advanced services",
                    #"return page.text().includes("Desktop services") && page.text().includes("No backups yet");"#
                )
                try await run(surface, #"page.select("Check service status again").click();"#)
                try await waitFor(
                    surface, "refresh completed",
                    #"return !page.select("Check service status again").disabled;"#)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
                #expect(
                    await harness.desktop.calls.allSatisfy {
                        !$0.arguments.contains("kickstart") && !$0.arguments.contains("SIGTERM")
                    })
                try harness.store.update { $0.currentTheme = "midnight" }
                try await waitFor(
                    surface, "outside theme", #"return page.text().includes("midnight");"#)
            }
        }

        @Test(
            "service restart and stop reach launchctl through the fake and keep the shell pill consistent"
        )
        func services() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                await harness.desktop.answer("launchctl") { arguments in
                    arguments.first == "print" ? .success("state = running\npid = 123") : .success()
                }
                let before = harness.settingsData
                let surface = try advancedPage(harness)
                let broadcast = StateBroadcast(settings: { surface }, switcher: { nil })
                broadcast.start(harness.model)
                defer { withExtendedLifetime(broadcast) {} }
                try await waitFor(
                    surface, "Advanced",
                    #"return !!page.select("Restart window arrangement") && page.select("Open desktop services")?.textContent.includes("4/4");"#
                )
                try await run(surface, #"page.select("Restart window arrangement").click();"#)
                try await waitUntil("fake kickstart") {
                    await harness.desktop.calls(to: "launchctl").contains {
                        $0.first == "kickstart"
                    }
                }
                try await waitFor(
                    surface, "restart settled",
                    #"return !page.select("Restart window arrangement").disabled;"#)
                await harness.desktop.answer("launchctl") { arguments in
                    arguments.first == "print" ? .failure("Stopped") : .success()
                }
                try await run(surface, #"page.select("Stop window arrangement").click();"#)
                try await waitFor(
                    surface, "confirm stop",
                    #"return document.querySelector('[role=alertdialog]')?.textContent.includes("Stopping yabai turns off");"#
                )
                let stoppedEarly = await harness.desktop.calls(to: "launchctl").contains {
                    $0.contains("SIGTERM")
                }
                #expect(!stoppedEarly)
                try await run(
                    surface,
                    #"[...document.querySelectorAll('[role=alertdialog] button')].find(b => b.textContent === "Stop yabai").click();"#
                )
                try await waitUntil("fake SIGTERM") {
                    await harness.desktop.calls(to: "launchctl").contains { $0.contains("SIGTERM") }
                }
                try await waitFor(
                    surface, "stopped state",
                    #"return page.select("Open desktop services")?.textContent.includes("0/4") && page.select("Stop window arrangement").disabled;"#
                )
                #expect(harness.model.shellState().services.running == 0)
                #expect(harness.settingsData == before)
            }
        }

        @Test("rebuilding writes generated files only when requested and reports drift")
        func rebuilds() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                let surface = try advancedPage(harness)
                try await waitFor(
                    surface, "Advanced",
                    #"return !!page.select("Rebuild window layout from preferences");"#)
                #expect(
                    !FileManager.default.fileExists(atPath: StartupConfiguration.yabairc.url.path))
                for label in ["window layout", "window borders", "menu bar"] {
                    try await run(
                        surface, "page.select(\"Rebuild \(label) from preferences\").click();")
                    try await waitFor(
                        surface, "rebuild settled",
                        #"return !page.select("Rebuild window layout from preferences").disabled;"#)
                }
                #expect(
                    FileManager.default.fileExists(atPath: StartupConfiguration.yabairc.url.path))
                #expect(
                    FileManager.default.fileExists(atPath: StartupConfiguration.bordersrc.url.path))
                #expect(
                    FileManager.default.fileExists(
                        atPath: StartupConfiguration.sketchybarrc.url.path))
                try await waitFor(
                    surface, "rebuild outcome", #"return page.text().includes("Rebuilt");"#)
            }
        }

        @Test("a snapshot needs confirmation and restoration is undoable")
        func restoreBackup() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: []) { harness in
                try harness.store.update { $0.currentTheme = nil }
                let store = SnapshotStore()
                let backup = try #require(
                    try store.capture([harness.store.url], reason: "original"))
                try harness.store.update { $0.mergeFlat(["YABAI_WINDOW_GAP": "21"]) }
                let before = harness.settingsData
                let surface = try advancedPage(harness)
                try await waitFor(
                    surface, "backup",
                    #"return !!document.querySelector('button[aria-label^="Restore backup from"]');"#
                )
                try await run(
                    surface,
                    #"document.querySelector('button[aria-label^="Restore backup from"]').click();"#
                )
                try await waitFor(
                    surface, "confirm restore",
                    #"return !!document.querySelector('[role=alertdialog]');"#)
                #expect(harness.settingsData == before)
                try await run(
                    surface,
                    #"[...document.querySelectorAll('[role=alertdialog] button')].find(b => b.textContent === "Restore").click();"#
                )
                try await waitUntil("restored settings") {
                    (try? harness.store.read().flatValues["YABAI_WINDOW_GAP"]) == nil
                }
                #expect(store.list().contains { $0.id != backup.id })
            }
        }

        @Test("an isolated run shows the scripting addition as unavailable with no repair")
        func additionUnavailable() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                let surface = try advancedPage(harness)
                try await waitFor(
                    surface, "unavailable addition",
                    #"return page.text().includes("Unavailable") && page.text().includes("Development runs never change the real sudoers rule.");"#
                )
                let repair = try await run(
                    surface,
                    #"return [...document.querySelectorAll('button')].some(b => b.textContent === "Repair");"#
                )
                #expect(repair as? Bool == false)
            }
        }

        @Test(
            "a failed service operation and a refused repair are visible without changing preferences"
        )
        func failures() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                await harness.desktop.answer("launchctl") { arguments in
                    arguments.first == "kickstart"
                        ? .failure("Restart refused") : .failure("Stopped")
                }
                let before = harness.settingsData
                let surface = try advancedPage(harness)
                try await waitFor(
                    surface, "Advanced", #"return !!page.select("Restart window arrangement");"#)
                try await run(surface, #"page.select("Restart window arrangement").click();"#)
                try await waitFor(
                    surface, "restart error",
                    #"return [...document.querySelectorAll('[role=alert]')].some(e => e.textContent.includes("Restart refused"));"#
                )
                var state = try await harness.model.advancedState()
                state.addition = "repair"
                surface.send(.advancedChanged(state))
                try await waitFor(
                    surface, "repair",
                    #"return [...document.querySelectorAll('button')].some(b => b.textContent === "Repair");"#
                )
                try await run(
                    surface,
                    #"[...document.querySelectorAll('button')].find(b => b.textContent === "Repair").click();"#
                )
                try await waitFor(
                    surface, "refused repair",
                    #"return page.text().includes("Development runs never change the real sudoers rule.");"#
                )
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.calls(to: "osascript").isEmpty)
            }
        }
    }
}
