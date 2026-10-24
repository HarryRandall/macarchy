import Foundation
import Testing

@testable import App
@testable import Macarchy

struct ShortcutsMessagesTests {
    @Test("ungrouped shortcuts encode section as explicit null, matching TypeScript")
    func nullSection() throws {
        let binding = ShortcutsState.Binding(
            id: 0, modifiers: ["cmd"], key: "k", caps: ["⌘", "K"], command: "echo custom",
            section: nil, passthrough: false, appOverrides: [])
        let data = try JSONEncoder().encode(binding)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["section"] is NSNull)
        #expect(object["command"] as? String == "echo custom")
    }

    @Test("the desktop count is sent, and an unknown count is an explicit null")
    func desktops() throws {
        let snapshot = ShortcutsSnapshot(revision: "version", bindings: [])
        func encoded(_ desktops: Int?) throws -> [String: Any] {
            let data = try JSONEncoder().encode(ShortcutsState(snapshot, desktops: desktops))
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        #expect(try encoded(3)["desktops"] as? Int == 3)
        #expect(try encoded(nil)["desktops"] is NSNull)
        #expect(try encoded(nil).keys.sorted() == ["bindings", "desktops", "revision"])
    }

    @Test("recorded input decodes as a chord and Swift renders the binding")
    func recordedInput() throws {
        let input = Data(
            #"{"id":1,"revision":"version","chord":{"modifiers":["cmd","shift"],"key":"k"}}"#.utf8)
        let params = try JSONDecoder().decode(ShortcutEditParams.self, from: input)
        let chord = try params.chord.validated()
        #expect(params.revision == "version")
        #expect(chord.keySpec == "shift + cmd - k")
        #expect(chord.caps == ["⇧", "⌘", "K"])
    }
}
