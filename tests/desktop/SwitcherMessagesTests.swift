import Foundation
import Testing

@testable import App
@testable import Macarchy

struct SwitcherMessagesTests {
    @Test("switcher.willOpen carries the state flat, with error as an explicit null")
    func openingEncoding() throws {
        let state = SwitcherState(themes: [], current: nil)
        let plain = try encoded(SwitcherOpening(state: state, error: nil))
        #expect(Set(plain.keys) == ["themes", "current", "error"])
        #expect(plain["current"] is NSNull)
        #expect(plain["error"] is NSNull)

        let failure = SwitcherFailure(title: "Could not apply Lumon", reason: "No yabai.")
        let failed = try encoded(SwitcherOpening(state: state, error: failure))
        let error = try #require(failed["error"] as? [String: Any])
        #expect(error["title"] as? String == "Could not apply Lumon")
        #expect(error["reason"] as? String == "No yabai.")
    }

    private func encoded(_ opening: SwitcherOpening) throws -> [String: Any] {
        let data = try JSONEncoder().encode(opening)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
