import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Report a problem page")
    struct ReportPageTests {
        @Test("drafts show redacted diagnostics and native actions share exactly the preview")
        func report() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .report)
                var copies: [String] = []
                var opened: [URL] = []
                surface.router.registerReport(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copies.append($0); return true
                        },
                        open: {
                            opened.append($0); return true
                        }, reveal: {}))
                try await reportReady(surface)
                #expect(copies.isEmpty && opened.isEmpty)
                try await run(
                    surface,
                    """
                    page.setValue(document.querySelector('input'), 'Bar disappears');
                    const description = document.querySelector('textarea');
                    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')
                      .set.call(description, 'A problem in ' + \(try json(harness.home.path)));
                    description.dispatchEvent(new Event('input', { bubbles: true }));
                    """)
                try await waitFor(
                    surface, "redacted draft",
                    """
                    const preview = document.querySelector('pre').innerText;
                    return preview.includes('A problem in ~') && !page.text().includes('Preparing…');
                    """)
                let preview = try #require(
                    try await run(surface, "return document.querySelector('pre').innerText;")
                        as? String)
                #expect(!preview.contains(harness.home.path))
                try await clickReportButton(surface, "Copy report")
                try await waitUntil("native report copy") { copies.count == 1 }
                #expect(copies == [preview])
                try await clickReportButton(surface, "Open on GitHub")
                try await waitUntil("native issue open") { opened.count == 1 }
                let url = try #require(opened.first)
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                #expect(query?.first { $0.name == "title" }?.value == "Bar disappears")
                #expect(query?.first { $0.name == "body" }?.value == preview)
                surface.send(.healthChanged)
                try await waitFor(
                    surface, "draft preserved",
                    "return document.querySelector('input').value === 'Bar disappears' && document.querySelector('textarea').value.startsWith('A problem');"
                )
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("refresh describes the changed desktop while typing reuses the last collection")
        func refresh() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                await harness.desktop.answer("skhd", ["--version"], with: .success("skhd-v0.3.9"))
                let (_, surface) = try harness.settingsPage(pane: .report)
                try await reportReady(surface)
                try await waitFor(
                    surface, "first diagnostics",
                    "return document.querySelector('pre').innerText.includes('skhd: skhd-v0.3.9');")
                let collected = await versionCalls(harness)
                await harness.desktop.answer("skhd", ["--version"], with: .success("skhd-v0.4.0"))
                try await run(
                    surface,
                    """
                    const description = document.querySelector('textarea');
                    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')
                      .set.call(description, 'After the fix');
                    description.dispatchEvent(new Event('input', { bubbles: true }));
                    """)
                try await waitFor(
                    surface, "draft with the earlier diagnostics",
                    """
                    const preview = document.querySelector('pre').innerText;
                    return preview.includes('After the fix') && preview.includes('skhd-v0.3.9')
                      && !page.text().includes('Preparing…');
                    """)
                #expect(await versionCalls(harness) == collected)
                let name = try await run(
                    surface,
                    "return [...document.querySelectorAll('button')].find(b => b.innerText === 'Refresh')?.getAttribute('aria-label');"
                )
                #expect(name as? String == "Refresh diagnostics")
                try await clickReportButton(surface, "Refresh")
                try await waitFor(
                    surface, "fresh diagnostics",
                    """
                    const preview = document.querySelector('pre').innerText;
                    return preview.includes('skhd: skhd-v0.4.0') && preview.includes('After the fix');
                    """)
            }
        }

        @Test("quick prepares share one collection and a later refresh collects again")
        func sharedCollection() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                await harness.desktop.answer("skhd", ["--version"], with: .success("skhd-v0.3.9"))
                let router = BridgeRouter()
                router.registerReport(
                    model: harness.model,
                    actions: DiagnosticActions(copy: { _ in true }, open: { _ in true }, reveal: {})
                )
                func prepare(_ description: String, refresh: Bool) async -> String {
                    await router.handle([
                        "method": "report.prepare",
                        "params": ["description": description, "refresh": refresh]
                    ])
                }
                _ = await prepare("", refresh: true)
                let perCollection = await versionCalls(harness)
                #expect(perCollection > 0)
                await harness.desktop.answer("skhd", ["--version"], with: .success("skhd-v0.4.0"))
                // Both requests reach the main actor before the collection's
                // first step does, so the second finds the first still running.
                let opening = Task { await prepare("", refresh: true) }
                let typing = Task { await prepare("Typed", refresh: false) }
                let replies = [await opening.value, await typing.value]
                #expect(await versionCalls(harness) == 2 * perCollection)
                #expect(
                    replies.allSatisfy { $0.contains("skhd-v0.4.0") },
                    "\(replies.map { $0.prefix(1500) })")
                await harness.desktop.answer("skhd", ["--version"], with: .success("skhd-v0.5.0"))
                let typed = await prepare("Typed again", refresh: false)
                #expect(typed.contains("skhd-v0.4.0"))
                #expect(await versionCalls(harness) == 2 * perCollection)
                let refreshed = await prepare("Typed again", refresh: true)
                #expect(refreshed.contains("skhd-v0.5.0"))
                #expect(await versionCalls(harness) == 3 * perCollection)
            }
        }

        @Test("native failures show an error without a successful notice")
        func failure() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .report)
                surface.router.registerReport(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: { _ in false }, open: { _ in false }, reveal: {}))
                try await reportReady(surface)
                try await clickReportButton(surface, "Copy report")
                try await waitFor(
                    surface, "copy failure",
                    "return document.querySelector('[role=alert]')?.innerText.includes('could not be copied');"
                )
                #expect(harness.settingsData == before)
            }
        }
    }
}

@MainActor
private func reportReady(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "diagnostic preview",
        """
        return document.querySelector('pre')?.innerText.includes('## Environment')
          && !page.text().includes('Preparing…');
        """)
}

@MainActor
private func clickReportButton(_ surface: WebSurface, _ title: String) async throws {
    try await run(
        surface,
        "[...document.querySelectorAll('button')].find(b => b.innerText === \(try json(title))).click();"
    )
}

/// How many times diagnostics asked skhd for its version, the same for every
/// collection, so counting them counts collections.
@MainActor
private func versionCalls(_ harness: Harness) async -> Int {
    await harness.desktop.calls(to: "skhd").filter { $0 == ["--version"] }.count
}

private func json(_ value: String) throws -> String {
    try #require(String(bytes: JSONEncoder().encode(value), encoding: .utf8))
}
