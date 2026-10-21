import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Overview native operations")
    struct OverviewBridgeTests {
        @Test("home bridge reads isolated state and encodes absent fields as null")
        func home() async throws {
            try await withHarness { harness in
                let before = harness.settingsData
                let router = BridgeRouter()
                router.registerHome(model: harness.model)
                let reply = try await overviewReply(router, "home.getState")
                #expect(reply["ok"] as? Bool == true)
                let value = try #require(reply["value"] as? [String: Any])
                #expect(value["theme"] as? String == "lumon")
                #expect(value["lastChange"] is NSNull)
                #expect(value["shortcutsCount"] as? Int == 0)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("health fixes are selected by check ID and native failures are reported")
        func health() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let router = BridgeRouter()
                var copied: [String] = []
                var reveals = 0
                router.registerHealth(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copied.append($0); return true
                        },
                        open: { _ in false }, reveal: { reveals += 1 }))
                let reply = try await overviewReply(router, "health.getState")
                let value = try #require(reply["value"] as? [String: Any])
                let checks = try #require(value["checks"] as? [[String: Any]])
                let fix = try #require(checks.first { $0["fix"] is String })
                let id = try #require(fix["id"] as? String)
                let copy = try await overviewReply(router, "health.copyFix", ["id": id])
                #expect(copy["ok"] as? Bool == true)
                #expect(copied == [fix["fix"] as? String].compactMap { $0 })
                let invalid = try await overviewReply(router, "health.copyFix", ["id": "arbitrary"])
                #expect(invalid["ok"] as? Bool == false)
                _ = try await overviewReply(router, "health.revealSettings")
                #expect(reveals == 1)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("report native actions send exactly the redacted preview and reject stale tokens")
        func report() async throws {
            try await withHarness(tools: []) { harness in
                let before = harness.settingsData
                let router = BridgeRouter()
                var copies: [String] = []
                var opened: [URL] = []
                router.registerReport(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copies.append($0); return true
                        },
                        open: {
                            opened.append($0); return true
                        }, reveal: {}))
                let reply = try await overviewReply(
                    router, "report.prepare",
                    ["description": harness.home.path, "refresh": true])
                let value = try #require(reply["value"] as? [String: Any])
                let token = try #require(value["token"] as? String)
                let body = try #require(value["body"] as? String)
                #expect(!body.contains(harness.home.path))
                #expect(copies.isEmpty && opened.isEmpty)
                _ = try await overviewReply(router, "report.copy", ["token": token])
                _ = try await overviewReply(
                    router, "report.openIssue", ["token": token, "title": "Test"])
                #expect(copies == [body])
                let url = try #require(opened.first)
                #expect(
                    URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                        .first { $0.name == "body" }?.value == body)
                _ = try await overviewReply(
                    router, "report.prepare", ["description": "New draft", "refresh": false])
                let stale = try await overviewReply(router, "report.copy", ["token": token])
                #expect(stale["ok"] as? Bool == false)
                #expect(copies.count == 1)
                #expect(harness.settingsData == before)
            }
        }

        @Test(
            "long report fallback copies the full body and clipboard or browser errors fail visibly"
        )
        func reportFallback() async throws {
            try await withHarness(tools: []) { harness in
                let router = BridgeRouter()
                var copies: [String] = []
                var opened: [URL] = []
                var clipboardAvailable = true
                var browserAvailable = true
                router.registerReport(
                    model: harness.model,
                    actions: DiagnosticActions(
                        copy: {
                            copies.append($0); return clipboardAvailable
                        },
                        open: {
                            opened.append($0); return browserAvailable
                        }, reveal: {}))
                let reply = try await overviewReply(
                    router, "report.prepare",
                    ["description": String(repeating: "test\n", count: 3000), "refresh": true])
                let value = try #require(reply["value"] as? [String: Any])
                let token = try #require(value["token"] as? String)
                let result = try await overviewReply(
                    router, "report.openIssue", ["token": token, "title": "Test"])
                #expect((result["value"] as? [String: Any])?["copied"] as? Bool == true)
                #expect(copies.first == value["body"] as? String)
                clipboardAvailable = false
                let copyFailure = try await overviewReply(router, "report.copy", ["token": token])
                #expect(copyFailure["ok"] as? Bool == false)
                let openFailure = try await overviewReply(
                    router, "report.openIssue", ["token": token, "title": "Test"])
                #expect(openFailure["ok"] as? Bool == false)
                #expect(opened.count == 1)
                clipboardAvailable = true
                browserAvailable = false
                let browserFailure = try await overviewReply(router, "report.openIssues")
                #expect(browserFailure["ok"] as? Bool == false)
            }
        }
    }
}

@MainActor
private func overviewReply(
    _ router: BridgeRouter, _ method: String,
    _ params: [String: Any] = [:]
) async throws -> [String: Any] {
    let reply = await router.handle(["method": method, "params": params])
    return try #require(JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any])
}
