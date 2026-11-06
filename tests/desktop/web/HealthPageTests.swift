import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Setup health page")
    struct HealthPageTests {
        @Test("checks, copy command and reveal use native operations and leave settings unchanged")
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
                      button.innerText.includes('Copy command')).click();
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

        @Test("advice reads as text, and a broken file offers Open rather than Copy")
        func adviceAndFile() async throws {
            try await withHarness(tools: []) { harness in
                try harness.write("{ not json", to: settingsFile)
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .health)
                var copied: [String] = []
                var opened: [URL] = []
                surface.router.registerHealth(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copied.append($0); return true
                        },
                        open: {
                            opened.append($0); return true
                        },
                        reveal: {}))
                let row = "document.querySelector('[data-check-id=\"Configuration/Settings\"]')"
                try await waitFor(surface, "settings check", "return !!\(row);")
                try await run(surface, "\(row).querySelector('[data-row-primary]').click();")
                try await waitFor(
                    surface, "advice as text",
                    """
                    const settings = \(row);
                    return settings.innerText.includes('Correct the file, or restore')
                      && !settings.querySelector('pre, code')
                      && ![...settings.querySelectorAll('button')]
                        .some(button => button.innerText.includes('Copy'));
                    """)
                try await run(
                    surface,
                    """
                    [...\(row).querySelectorAll('button')]
                      .find(button => button.innerText.includes('Open settings.json')).click();
                    """)
                try await waitUntil("opened settings") { !opened.isEmpty }
                #expect(
                    opened.map { $0.resolvingSymlinksInPath().path }
                        == [harness.store.url.resolvingSymlinksInPath().path])
                #expect(copied.isEmpty)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("a taken switcher shortcut shows as a warning with what to do")
        func takenShortcut() async throws {
            try await withHarness(tools: []) { harness in
                let (_, surface) = try harness.settingsPage(pane: .health)
                surface.router.registerHealth(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: { _ in false }, open: { _ in false }, reveal: {}),
                    appChecks: { ThemeSwitcher.healthChecks(shortcutTaken: true) })
                let row =
                    "document.querySelector('[data-check-id=\"Optional/Theme switcher shortcut\"]')"
                try await waitFor(surface, "the shortcut check", "return !!\(row);")
                try await run(surface, "\(row).querySelector('[data-row-primary]').click();")
                try await waitFor(
                    surface, "its advice",
                    """
                    const check = \(row);
                    return check.innerText.includes('Emoji & Symbols')
                      && check.innerText.includes('Keyboard Shortcuts');
                    """)
                #expect(ThemeSwitcher.healthChecks(shortcutTaken: false).isEmpty)
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
                    "[...document.querySelectorAll('button')].find(b => b.innerText.includes('Copy command')).click();"
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
