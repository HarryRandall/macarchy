import AppKit

/// InstantSpaceSwitcher, which earlier versions installed and ran beside
/// Macarchy before it switched Spaces itself.
///
/// Macarchy never uninstalls it. While it runs, its hotkeys and swipe
/// override still switch Spaces, and on macOS 27 it takes Macarchy's swipes
/// for a trackpad's and sends its own, which overshoots and drops presses.
/// So Health says to quit it.
public enum InstantSpaceSwitcher {
    public static let bundleIdentifier = "com.interversehq.InstantSpaceSwitcher"

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }
}
