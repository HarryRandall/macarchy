import Foundation
import Macarchy
import ServiceManagement

/// Opening Macarchy at login. The app feeds the bar's widgets, so without it
/// they keep their last values. The first launch after setup turns it on,
/// once; after that it is the person's choice, on the Advanced page or in
/// System Settings, and a choice to turn it off is never undone.
///
/// Debug builds and isolated runs share the installed app's bundle
/// identifier, so they never register or read it: a development copy at
/// login would be the wrong app.
@MainActor
struct LoginItem {
    enum State: String, Codable, Sendable {
        case on, off
        /// Registered, waiting for the person to allow it in System Settings.
        case approval
        /// A development run, which leaves login items alone.
        case unavailable
    }

    var state: () -> State
    var setEnabled: (Bool) throws -> Void
    var openSettings: () -> Void
    /// Whether the first launch after setup has turned it on already.
    var offered: () -> Bool = { Preferences.store.bool(forKey: LoginItem.offeredKey) }
    var markOffered: () -> Void = { Preferences.store.set(true, forKey: LoginItem.offeredKey) }

    static var current: LoginItem {
        guard !isDevelopmentRun else {
            return LoginItem(
                state: { .unavailable },
                setEnabled: { _ in
                    throw ConfigurationError("A development copy does not open at login.")
                }, openSettings: {})
        }
        return LoginItem(
            state: {
                switch SMAppService.mainApp.status {
                case .enabled: .on
                case .requiresApproval: .approval
                default: .off
                }
            },
            setEnabled: { enabled in
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            },
            openSettings: { SMAppService.openSystemSettingsLoginItems() })
    }

    static var isDevelopmentRun: Bool {
        #if DEBUG
        true
        #else
        Paths.isolated
        #endif
    }

    static let offeredKey = "loginItemOffered"

    /// Turns opening at login on the first time the app runs set up, and
    /// never again, so turning it off sticks. Returns why it could not, if so.
    @discardableResult
    func turnOnOnce() -> String? {
        guard state() != .unavailable, !offered(),
            FileManager.default.fileExists(atPath: Paths.settings.path)
        else { return nil }
        markOffered()
        guard state() == .off else { return nil }
        do {
            try setEnabled(true)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
