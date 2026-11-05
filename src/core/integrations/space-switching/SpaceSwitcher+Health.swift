import Foundation

extension SpaceSwitcher {
    /// Whether Spaces switch through the app, read from its lock so the
    /// command and the app agree whichever process asks. While the app is
    /// not switching, each `macarchy space` switches itself with skhd's
    /// permission, which works but cannot share the app's queue.
    static func healthChecks(
        appSwitching: Bool = PresenceLock.isHeld(at: SpaceSwitchRequest.presenceURL),
        oldSwitcherRunning: Bool = InstantSpaceSwitcher.isRunning
    ) -> [HealthCheck] {
        var checks = [
            appSwitching
                ? HealthCheck(
                    .optional, "Instant Space switching", .passed,
                    "Macarchy switches Spaces at once, one at a time")
                : HealthCheck(
                    .optional, "Instant Space switching", .unknown,
                    "Each shortcut switches on its own until Macarchy may control the computer",
                    fix: "Allow Macarchy in System Settings → Privacy & Security → Accessibility. "
                        + "It starts switching within half a minute.")
        ]
        if oldSwitcherRunning {
            checks.append(
                HealthCheck(
                    .optional, "InstantSpaceSwitcher", .warning,
                    "Still running, so its hotkeys and swipe override compete with Macarchy's "
                        + "switching",
                    fix: "Quit it and remove it from Login Items. Macarchy no longer needs it.",
                    command: "brew uninstall --cask jurplel/tap/instant-space-switcher"))
        }
        return checks
    }
}
