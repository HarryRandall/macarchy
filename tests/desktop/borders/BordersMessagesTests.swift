import Foundation
import Testing

@testable import App
@testable import Macarchy

struct BordersMessagesTests {
    @Test("the border state encodes optional fields as explicit nulls")
    func explicitNulls() throws {
        let state = BordersState(
            appearance: BorderAppearance(), applicationIcons: [:], theme: nil, defaults: nil,
            unavailableReason: nil, wallpaper: nil)
        let data = try JSONEncoder().encode(state)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["theme", "defaults", "unavailableReason", "wallpaper"] {
            #expect(object[key] is NSNull)
        }
        let appearance = try #require(object["appearance"] as? [String: Any])
        for key in ["radius", "activeColour", "inactiveColour"] {
            #expect(appearance[key] is NSNull)
        }
        #expect(
            try JSONDecoder().decode(
                BorderAppearance.self, from: JSONEncoder().encode(BorderAppearance()))
                == BorderAppearance())
    }

    @Test("cancelling the application picker returns null without a command")
    @MainActor
    func cancelledPicker() async throws {
        let router = BridgeRouter()
        let model = AppModel(
            backend: Integrations { _, _ in
                Issue.record("A cancelled picker must not execute desktop commands.")
                return CommandResult(command: "unexpected", status: 1)
            })
        router.registerBorders(model: model, pickApplication: { nil })
        let reply = await router.handle(["method": "borders.pickApplication", "params": [:]])
        let data = try #require(reply.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["ok"] as? Bool == true)
        #expect(object["value"] is NSNull)
    }
}
