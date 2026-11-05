import Foundation

/// A Space shortcut, as `macarchy space` passes it to the app.
///
/// The app runs the one `SpaceSwitcher` while it can post events, and holds
/// a lock on `state/space-switcher.lock` for as long as it does. The command
/// hands a request over while that lock is held, so every switch goes
/// through the same queue. Otherwise it switches itself (`SpaceSwitch`): run
/// from skhd, skhd's Accessibility covers it.
public struct SpaceSwitchRequest: Equatable, Sendable {
    /// The Space's index, as yabai numbers it.
    public var space: Int
    /// Move the focused window there and follow it.
    public var move: Bool

    public init(space: Int, move: Bool = false) {
        self.space = space
        self.move = move
    }

    public static let notification = Notification.Name(
        "io.github.harryrandall.macarchy.space.switch")

    public static var presenceURL: URL {
        Paths.stateDirectory.appending(path: "space-switcher.lock")
    }

    public var userInfo: [AnyHashable: Any] { ["space": space, "move": move] }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let space = userInfo?["space"] as? Int, space > 0 else { return nil }
        self.init(space: space, move: userInfo?["move"] as? Bool ?? false)
    }

    /// Hands the request to the app when it is switching, otherwise switches
    /// in this process. Returns whether it was handed over. Either way the
    /// Space is recorded first, as yabai's refocus signal reads it to hold
    /// back while a switch is on its way: focusing a window on the Space
    /// being left would switch back to it.
    @discardableResult
    public func perform(
        appSwitching: Bool = PresenceLock.isHeld(at: presenceURL),
        record: (Int) -> Void = { SpaceSwitch.record($0, in: Paths.stateDirectory) },
        handOff: (SpaceSwitchRequest) -> Void = { AppNotice.post(notification, $0.userInfo) },
        here: (SpaceSwitchRequest) async -> Void = { request in
            let switcher = SpaceSwitch.live
            if request.move {
                await switcher.move(to: request.space)
            } else {
                await switcher.go(to: request.space)
            }
        }
    ) async -> Bool {
        if appSwitching {
            record(space)
            handOff(self)
            return true
        }
        await here(self)
        return false
    }
}
