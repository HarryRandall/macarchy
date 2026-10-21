import AppKit
import SwiftUI

/// The SwiftUI settings window, for the panes not yet migrated and for setup.
///
/// It is an AppKit window around the classic root view rather than a SwiftUI
/// `Window` scene, because a scene opens itself whenever SwiftUI decides the
/// app needs a window, and can only be opened from inside a view. Owned here,
/// it opens exactly when asked, from anywhere.
@MainActor
final class ClassicWindow {
    static let shared = ClassicWindow()

    private var window: NSWindow?

    func show(_ model: AppModel) {
        let window = window ?? make(model)
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func make(_ model: AppModel) -> NSWindow {
        let root = RootView()
            .environment(model)
            .task { await model.loadEverything() }
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.title = "Macarchy"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 1000, height: 720))
        if !window.setFrameUsingName("MacarchyClassic") { window.center() }
        window.setFrameAutosaveName("MacarchyClassic")
        return window
    }
}
