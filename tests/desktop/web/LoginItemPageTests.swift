import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Opening Macarchy at login, from the Advanced page and after setup.
    @MainActor
    @Suite("Open at login")
    struct LoginItemPageTests {
        @Test(
            "opening at login turns on and off, asks for approval, and a development copy never does"
        )
        func loginItem() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                let recorder = LoginItemRecorder()
                let surface = try harness.settingsPage(pane: .advanced).1
                try await waitFor(
                    surface, "development copy",
                    #"return page.disabled(page.toggle("Open Macarchy at login")) && page.text().includes("Development copies never open at login.");"#
                )
                harness.model.loginItem = recorder.item
                try await run(surface, #"page.select("Check service status again").click();"#)
                try await waitFor(
                    surface, "off",
                    #"const t = page.toggle("Open Macarchy at login"); return !page.disabled(t) && t.getAttribute("aria-checked") === "false";"#
                )
                try await run(surface, #"page.toggle("Open Macarchy at login").click();"#)
                try await waitFor(
                    surface, "on",
                    #"return page.toggle("Open Macarchy at login").getAttribute("aria-checked") === "true";"#
                )
                #expect(recorder.calls == [true])
                recorder.state = .approval
                try await run(surface, #"page.select("Check service status again").click();"#)
                try await waitFor(
                    surface, "approval",
                    #"return [...document.querySelectorAll('button')].some(b => b.textContent === "Open Login Items");"#
                )
                try await run(
                    surface,
                    #"[...document.querySelectorAll('button')].find(b => b.textContent === "Open Login Items").click();"#
                )
                try await waitUntil("Login Items opened") { recorder.opened == 1 }
                try await run(surface, #"page.toggle("Open Macarchy at login").click();"#)
                try await waitFor(
                    surface, "off again",
                    #"return page.toggle("Open Macarchy at login").getAttribute("aria-checked") === "false";"#
                )
                #expect(recorder.calls == [true, false])
            }
        }

        @Test("the first launch after setup opens at login once, and never again")
        func loginItemOnce() async throws {
            try await withHarness { harness in
                let recorder = LoginItemRecorder()
                let saved = harness.settingsData
                try FileManager.default.removeItem(at: harness.store.url)
                #expect(recorder.item.turnOnOnce() == nil)
                #expect(recorder.calls.isEmpty, "Setup has not run, so nothing is turned on")
                try saved.write(to: harness.store.url)
                recorder.item.turnOnOnce()
                #expect(recorder.calls == [true])
                recorder.state = .off
                recorder.item.turnOnOnce()
                #expect(recorder.calls == [true], "Turning it off afterwards sticks")
            }
        }

        @Test("uninstall stops the app opening at login and says so")
        func uninstallStopsLoginItem() async throws {
            try await withHarness { harness in
                #expect(LoginItem.isDevelopmentRun)
                #expect(OpenAtLogin.stop() == nil)
                let session = SetupSession(
                    integrations: harness.model.backend,
                    stopOpeningAtLogin: { "Macarchy no longer opens at login" })
                let report = try await session.restoreOriginals()
                #expect(report.lines.contains("Macarchy no longer opens at login"))
            }
        }
    }
}

/// Stands in for the login item, recording what the page asked of it.
@MainActor
final class LoginItemRecorder {
    var state: LoginItem.State = .off
    var calls: [Bool] = []
    var opened = 0
    var offered = false

    var item: LoginItem {
        LoginItem(
            state: { self.state },
            setEnabled: { enabled in
                self.calls.append(enabled)
                self.state = enabled ? .on : .off
            },
            openSettings: { self.opened += 1 }, offered: { self.offered },
            markOffered: { self.offered = true })
    }
}
