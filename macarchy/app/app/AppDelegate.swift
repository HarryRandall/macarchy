import AppKit

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

    /// SwiftUI only hands out `openWindow` to views. The status item label lives
    /// as long as the process, so it supplies the action for AppKit callbacks.
    static var openMainWindow: (() -> Void)?

    /// Brings the Dock icon back before the window opens so it activates normally.
    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openMainWindow?()
        NSApp.activate()
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
