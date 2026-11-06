import Foundation

extension SpaceSwitcher {
    /// Whether Spaces switch through the app, read from its lock so the
    /// command and the app agree whichever process asks. While the app is
    /// not switching, each `macarchy space` switches itself with skhd's
    /// permission, which works but cannot share the app's queue.
    static func healthChecks(
        appSwitching: Bool = PresenceLock.isHeld(at: SpaceSwitchRequest.presenceURL)
    ) -> [HealthCheck] {
        [
            appSwitching
                ? HealthCheck(
                    .optional, "Instant Space switching", .passed,
                    "Macarchy switches Spaces at once, one at a time")
                : HealthCheck(
                    .optional, "Instant Space switching", .unknown,
                    "Each shortcut switches on its own until Macarchy may control the computer",
                    fix: "Allow Macarchy in System Settings → Privacy & Security → Accessibility. "
                        + "It starts switching within a few seconds.")
        ]
    }
}
