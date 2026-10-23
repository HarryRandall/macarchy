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
        // The classic SwiftUI window no longer opens itself at launch; this
        // is where the app's window comes from now.
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
    /// moved or replaced since setup, point the link at this copy. Before
    /// setup there is no link, and opening the app changes nothing.
    private func repairAppLink() {
        let bundle = Bundle.main.bundleURL
        guard !Self.isDevelopmentRun, bundle.pathExtension == "app",
            let current = try? FileManager.default.destinationOfSymbolicLink(
                atPath: Paths.appLink.path),
            current != bundle.resolvingSymlinksInPath().path
        else { return }
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

    /// Shows the settings window: the React one, or the classic one while
    /// setup has yet to run.
    static func showMainWindow() {
        SettingsWindow.shared.show()
    }

    /// Opens the SwiftUI window for the editors that have not moved to React,
    /// optionally at a pane and with its search or console showing.
    static func showClassicWindow(pane: Pane?, show: OpenClassicParams.Show?) {
        guard let model else { return }
        if let pane, pane.opensInClassic { model.selection = pane }
        ClassicWindow.shared.show(model)
        switch show {
        case .search: model.modal.present(inContent: true) { CommandPalette() }
        case .console: model.consoleOpen = true
        case nil: break
        }
    }

    static weak var model: AppModel?

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
