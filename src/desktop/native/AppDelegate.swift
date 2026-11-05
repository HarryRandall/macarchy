import AppKit
import Macarchy

/// Keeps Macarchy in the menu bar after its window is gone, like Docker Desktop.
///
/// Cmd-Q, the Dock's Quit item and closing the last window all drop the Dock
/// icon and leave the status item running. Only the status menu's Quit, or a
/// logout, restart or shutdown, ends the process.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var quitting = false
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        repairAppLink()
        WidgetHostController.shared.start()
        WidgetMenuController.shared.start()
        SpaceSwitcherController.shared.start()
        Self.showMainWindow()
        #if DEBUG
        // A development build cannot register ⌘⌃Space while an installed copy
        // holds it, and `macarchy switcher` would open both. This name only
        // reaches debug builds.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("io.github.harryrandall.macarchy.debug.switcher"),
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ThemeSwitcher.shared.toggle() }
        }
        #endif
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { notification in
            let closing = notification.object as? NSWindow
            MainActor.assumeIsolated {
                // The status menu's own panel is not a window the Dock icon stands for.
                guard let closing, closing.canBecomeMain else { return }
                let remaining = NSApp.windows.filter {
                    $0 !== closing && $0.canBecomeMain && $0.isVisible
                }
                if remaining.isEmpty { AppDelegate.hideToMenuBar() }
            }
        }
    }

    /// Startup files reach the CLI through a link to the app. If the app was
    /// moved or replaced since setup, or the link went missing, point it at
    /// this copy. Before setup there is nothing to link, and opening the app
    /// changes nothing.
    private func repairAppLink() {
        let bundle = Bundle.main.bundleURL
        guard !Self.isDevelopmentRun, bundle.pathExtension == "app",
            FileManager.default.fileExists(atPath: Paths.settings.path)
        else { return }
        let current = try? FileManager.default.destinationOfSymbolicLink(
            atPath: Paths.appLink.path)
        guard current != bundle.resolvingSymlinksInPath().path else { return }
        try? Setup.link(bundle)
    }

    /// Debug builds and runs with their own home never repoint the app link,
    /// so only an installed copy becomes the one startup files run.
    private static var isDevelopmentRun: Bool {
        #if DEBUG
        true
        #else
        Paths.isolated
        #endif
    }

    /// Relaunching from Finder or Spotlight while hidden reopens the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.showMainWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.quitting || Self.systemIsEndingSession() { return .terminateNow }
        for window in NSApp.windows where window.canBecomeMain { window.close() }
        Self.hideToMenuBar()
        return .terminateCancel
    }

    /// Ends the process. Only the status menu offers this.
    static func quit() {
        quitting = true
        NSApp.terminate(nil)
    }

    /// Shows the settings window.
    static func showMainWindow() {
        SettingsWindow.shared.show()
    }

    private static func hideToMenuBar() {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Logout, restart and shutdown send a quit event carrying a reason. Cancelling
    /// those would stall the session, so they always terminate.
    private static func systemIsEndingSession() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
            event.eventClass == kCoreEventClass, event.eventID == kAEQuitApplication
        else { return false }
        return event.attributeDescriptor(forKeyword: kAEQuitReason) != nil
    }
}
