import AppKit
import Macarchy

/// Runs the one `SpaceSwitcher` every Space shortcut goes through.
///
/// While this process may post events it holds the switcher lock, so
/// `macarchy space` hands its requests here instead of switching itself
/// (`SpaceSwitchRequest`). Permission can be given or taken away while the
/// app runs, so it looks again every half minute and lets the lock go when
/// it can no longer switch.
@MainActor
final class SpaceSwitcherController {
    static let shared = SpaceSwitcherController()

    private let switcher = SpaceSwitcher.live()
    private var presence: Int32?
    private var check: Timer?
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SpaceSwitchRequest.notification, object: nil, queue: .main
        ) { notification in
            guard AppNotice.isForThisCopy(notification),
                let request = SpaceSwitchRequest(userInfo: notification.userInfo)
            else { return }
            MainActor.assumeIsolated { SpaceSwitcherController.shared.handle(request) }
        }
        updatePresence()
        check = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { SpaceSwitcherController.shared.updatePresence() }
        }
    }

    /// Each request runs on its own, so a press made while a switch lands
    /// reaches the switcher and is recorded, rather than waiting behind it.
    private func handle(_ request: SpaceSwitchRequest) {
        let switcher = switcher
        Task {
            if request.move {
                await switcher.move(to: request.space)
            } else {
                await switcher.go(to: request.space)
            }
        }
    }

    private func updatePresence() {
        if SpaceSwitcher.gesturesAllowed {
            if presence == nil { presence = PresenceLock.hold(at: SpaceSwitchRequest.presenceURL) }
        } else if let held = presence {
            close(held)
            presence = nil
        }
    }
}
