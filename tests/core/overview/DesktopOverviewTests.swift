import Foundation
import Testing

@testable import Macarchy

struct DesktopOverviewTests {
    @Test("summary reads themes, shortcuts, observed layout and services without writing")
    func readOnlySummary() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "overview-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        try store.update { $0.currentTheme = "lumon" }
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "resources/themes")
        let shortcuts = root.appending(path: "skhdrc")
        try "ctrl - a : echo a\nctrl - b : echo b\n# disabled: ctrl - c : echo c\n".write(
            to: shortcuts, atomically: true, encoding: .utf8)
        let before = try Data(contentsOf: store.url)
        let backend = Integrations { path, arguments in
            if URL(fileURLWithPath: path).lastPathComponent == "launchctl" {
                return CommandResult(
                    command: "fake service", status: 0,
                    stdout: "state = running\npid = 42")
            }
            #expect(arguments.count == 3)
            return CommandResult(
                command: "fake read", status: 0,
                stdout: arguments.last == "layout" ? "stack" : "8")
        }
        let summary = try await DesktopOverview(
            integrations: backend, store: store, themes: resources, shortcuts: shortcuts,
            snapshots: SnapshotStore(root: root.appending(path: "snapshots"))
        ).read()
        #expect(summary.theme == "lumon")
        #expect(summary.themeCount == 8)
        #expect(summary.shortcutsCount == 2)
        #expect(summary.layout == .stack)
        #expect(summary.running == Daemon.allCases.count)
        #expect(summary.lastChange == nil)
        #expect(try Data(contentsOf: store.url) == before)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "snapshots").path))
    }

    @Test("invalid settings fail rather than showing a default summary")
    func invalidSettings() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "overview-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "settings.json")
        try Data("broken".utf8).write(to: file)
        let backend = Integrations { _, _ in
            Issue.record("Invalid settings must fail before running commands")
            return CommandResult(command: "unexpected", status: 1)
        }
        await #expect(throws: (any Error).self) {
            try await DesktopOverview(integrations: backend, store: SettingsStore(url: file)).read()
        }
    }

    @Test("report preview is redacted and long submissions preserve the complete body")
    func reportSubmission() throws {
        let facts = Diagnostics.Environment(
            app: "test", macOS: "26", model: "Test Mac", architecture: "Apple Silicon", tools: [])
        let snapshot = DiagnosticSnapshot(
            checks: [HealthCheck(.services, "skhd", .failed, "Stopped", fix: "private fix")],
            environment: facts, checkedAt: .now)
        let body = snapshot.report(description: "Problem in \(NSHomeDirectory())")
        #expect(!body.contains(NSHomeDirectory()))
        #expect(!body.contains("private fix"))
        let report = ProblemReport(redactedBody: body)
        let submission = try report.submission(title: "A problem")
        #expect(!submission.copyBody)
        #expect(
            URLComponents(url: submission.url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "body" }?.value == body)
        let long = ProblemReport(redactedBody: String(repeating: "facts\n", count: 3000))
        let fallback = try long.submission(title: "A problem")
        #expect(fallback.copyBody)
        #expect(long.body.count == 18000)
        #expect(
            URLComponents(url: fallback.url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "body" }?.value?.isEmpty == true)
        #expect(throws: ConfigurationError.self) { try report.submission(title: "  ") }
        #expect(throws: ConfigurationError.self) {
            try long.submission(title: String(repeating: "x", count: 9000))
        }
    }
}
