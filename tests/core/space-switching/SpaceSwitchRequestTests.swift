import Foundation
import Testing

@testable import Macarchy

struct SpaceSwitchRequestTests {
    @Test("a request survives the notification's user info")
    func roundTrip() {
        let request = SpaceSwitchRequest(space: 3, move: true)
        #expect(SpaceSwitchRequest(userInfo: request.userInfo) == request)
        #expect(SpaceSwitchRequest(userInfo: ["space": 4]) == SpaceSwitchRequest(space: 4))
    }

    @Test("a notice without a Space, or with one below 1, is not a request")
    func refusesBadNotices() {
        #expect(SpaceSwitchRequest(userInfo: nil) == nil)
        #expect(SpaceSwitchRequest(userInfo: ["move": true]) == nil)
        #expect(SpaceSwitchRequest(userInfo: ["space": "3"]) == nil)
        #expect(SpaceSwitchRequest(userInfo: ["space": 0]) == nil)
    }

    @Test("while the app is switching, the request goes to it and nothing switches here")
    func handsOffToTheApp() async {
        var recorded: [Int] = []
        var handedOff: [SpaceSwitchRequest] = []
        var here: [SpaceSwitchRequest] = []
        let request = SpaceSwitchRequest(space: 2, move: true)
        let handed = await request.perform(
            appSwitching: true, record: { recorded.append($0) },
            handOff: { handedOff.append($0) }, here: { here.append($0) })
        #expect(handed)
        #expect(recorded == [2], "the refocus signal reads the Space pressed")
        #expect(handedOff == [request])
        #expect(here.isEmpty)
    }

    @Test("without the app switching, the command switches itself")
    func switchesHere() async {
        var handedOff: [SpaceSwitchRequest] = []
        var here: [SpaceSwitchRequest] = []
        let request = SpaceSwitchRequest(space: 5)
        // Switching here records it itself, in `SpaceSwitch`.
        let handed = await request.perform(
            appSwitching: false, record: { _ in Issue.record("recorded twice") },
            handOff: { handedOff.append($0) }, here: { here.append($0) })
        #expect(!handed)
        #expect(here == [request])
        #expect(handedOff.isEmpty)
    }

    @Test("the switcher lock is seen while the app holds it, and not after")
    func presence() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "switcher-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: "state/space-switcher.lock")
        #expect(!PresenceLock.isHeld(at: url))
        let held = try #require(PresenceLock.hold(at: url))
        #expect(PresenceLock.isHeld(at: url))
        #expect(PresenceLock.hold(at: url) == nil)
        close(held)
        #expect(!PresenceLock.isHeld(at: url))
    }
}
