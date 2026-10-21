import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Setup health page")
    struct HealthPageTests {
        @Test("checks, copy fix and reveal use native operations and leave settings unchanged")
        func health() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .health)
                var copied: [String] = []
                var reveals = 0
                surface.router.registerHealth(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copied.append($0); return true
                        },
                        open: { _ in
                            Issue.record("Unexpected browser open"); return false
                        },
                        reveal: { reveals += 1 }))
                try await waitFor(
                    surface, "health findings",
                    """
                    return page.text().includes('Not installed') && page.text().includes('This Mac')
                      && page.text().includes('Settings folder');
                    """)
                try await run(
                    surface,
                    """
                    [...document.querySelectorAll('button')].find(button =>
                      button.innerText.includes('Copy fix')).click();
                    """)
                try await waitUntil("copied native fix") { !copied.isEmpty }
                #expect(copied.first?.contains("brew install") == true)
                try await run(
                    surface,
                    "[...document.querySelectorAll('button')].find(b => b.innerText === 'Reveal').click();"
                )
                try await waitUntil("reveal") { reveals == 1 }
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
                try harness.install("skhd")
                surface.send(.healthChanged)
                try await waitFor(
                    surface, "external dependency change",
                    "return page.text().includes('Not set to start at login');")
                #expect(harness.settingsData == before)
            }
        }

        @Test("clipboard failures remain visible without changing settings")
        func failure() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .health)
                surface.router.registerHealth(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: { _ in false }, open: { _ in false }, reveal: {}))
                try await waitFor(
                    surface, "health checks", "return page.text().includes('Not installed');")
                try await run(
                    surface,
                    "[...document.querySelectorAll('button')].find(b => b.innerText.includes('Copy fix')).click();"
                )
                try await waitFor(
                    surface, "copy error",
                    "return document.querySelector('[role=alert]')?.innerText.includes('could not be copied');"
                )
                #expect(harness.settingsData == before)
            }
        }
    }
}
