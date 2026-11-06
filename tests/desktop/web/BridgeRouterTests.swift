import Foundation
import Testing

@testable import App

@MainActor
struct BridgeRouterTests {
    private struct Echo: Codable { var text: String }

    private func reply(_ json: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test("a registered method replies with its value in an ok envelope")
    func okReply() async throws {
        let router = BridgeRouter()
        router.register("echo") { (params: Echo) in params }
        let body: [String: Any] = ["method": "echo", "params": ["text": "hi"]]
        let result = try reply(await router.handle(body))
        #expect(result["ok"] as? Bool == true)
        #expect((result["value"] as? [String: Any])?["text"] as? String == "hi")
    }

    @Test("a method returning nothing replies with null")
    func nullReply() async throws {
        let router = BridgeRouter()
        router.register("noop") { (_: Empty) in Null() }
        let json = await router.handle(#"{"method":"noop","params":{}}"#)
        #expect(json == #"{"ok":true,"value":null}"#)
    }

    @Test("unknown methods, bad parameters and failures are typed errors")
    func errors() async throws {
        let router = BridgeRouter()
        router.register("echo") { (params: Echo) in params }
        router.register("fails") { (_: Empty) -> Null in
            throw BridgeFailure(.operationFailed, "yabai did not accept it.")
        }

        let unknown = try reply(await router.handle(["method": "shell.run", "params": [:]]))
        #expect((unknown["error"] as? [String: Any])?["code"] as? String == "unknown_method")

        let invalid = try reply(await router.handle(["method": "echo", "params": ["text": 4]]))
        #expect((invalid["error"] as? [String: Any])?["code"] as? String == "invalid_params")

        let failed = try reply(await router.handle(["method": "fails"]))
        let error = try #require(failed["error"] as? [String: Any])
        #expect(error["code"] as? String == "operation_failed")
        #expect(error["message"] as? String == "yabai did not accept it.")

        let malformed = try reply(await router.handle("not json"))
        #expect(malformed["ok"] as? Bool == false)
    }
}

struct AppSchemeTests {
    private func themes() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-scheme-test-\(UUID())")
        let backgrounds = root.appending(path: "lumon/backgrounds")
        try FileManager.default.createDirectory(at: backgrounds, withIntermediateDirectories: true)
        try Data([0]).write(to: backgrounds.appending(path: "1-office.png"))
        try Data([0]).write(to: root.appending(path: "lumon/theme.json"))
        try Data([0]).write(to: root.appending(path: "secret.png"))
        return root
    }

    @Test("theme images resolve only inside their theme")
    func themeImagesStayInside() throws {
        let root = try themes()
        defer { try? FileManager.default.removeItem(at: root) }
        func resolve(_ path: String) -> URL? {
            URL(string: "macarchy-app://media\(path)").flatMap {
                AppScheme.themeImage(for: $0, themesDirectory: root)
            }
        }
        #expect(resolve("/theme/lumon/backgrounds/1-office.png") != nil)
        #expect(resolve("/theme/lumon/../secret.png") == nil)
        #expect(resolve("/theme/lumon/%2E%2E/secret.png") == nil)
        #expect(resolve("/theme/lumon/theme.json") == nil)
        #expect(resolve("/theme/lumon/missing.png") == nil)
        #expect(resolve("/elsewhere/lumon/backgrounds/1-office.png") == nil)
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "lumon/backgrounds/2-escape.png"),
            withDestinationURL: root.appending(path: "secret.png"))
        #expect(resolve("/theme/lumon/backgrounds/2-escape.png") == nil)
    }

    @Test("built theme image URLs round-trip through the resolver")
    func urlsRoundTrip() throws {
        let root = try themes()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = AppScheme.themeImageURL(
            theme: "lumon", path: "backgrounds/1-office.png", maxPixels: 700)
        #expect(url.hasPrefix("macarchy-app://media/theme/lumon/"))
        let resolved = AppScheme.themeImage(
            for: try #require(URL(string: url)), themesDirectory: root)
        #expect(resolved?.lastPathComponent == "1-office.png")
    }
}
