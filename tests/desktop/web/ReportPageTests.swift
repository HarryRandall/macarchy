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

private func json(_ value: String) throws -> String {
    try #require(String(bytes: JSONEncoder().encode(value), encoding: .utf8))
}
