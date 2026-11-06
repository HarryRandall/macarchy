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
    /// Swap the windows of the desktop showing with that one's, and follow.
    public var swap: Bool

    public init(space: Int, move: Bool = false, swap: Bool = false) {
        self.space = space
        self.move = move
        self.swap = swap
    }

    public static let notification = Notification.Name(
        "io.github.harryrandall.macarchy.space.switch")

    public static var presenceURL: URL {
        Paths.stateDirectory.appending(path: "space-switcher.lock")
    }

    public var userInfo: [AnyHashable: Any] { ["space": space, "move": move, "swap": swap] }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let space = userInfo?["space"] as? Int, space > 0 else { return nil }
        self.init(
            space: space, move: userInfo?["move"] as? Bool ?? false,
            swap: userInfo?["swap"] as? Bool ?? false)
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
        here: (SpaceSwitchRequest) async -> Void = { await $0.performHere() }
    ) async -> Bool {
        if appSwitching {
            record(space)
            handOff(self)
            return true
        }
        await here(self)
        return false
    }

    /// Switches in this process. A swap runs a switcher of its own, as it
    /// is not queued with other presses across processes.
    public func performHere() async {
        if swap {
            await SpaceSwitcher(desktop: .live()).swap(with: space)
            return
        }
        let switcher = SpaceSwitch.live
        if move {
            await switcher.move(to: space)
        } else {
            await switcher.go(to: space)
        }
    }
}
