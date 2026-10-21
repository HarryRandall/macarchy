import AppKit
import SwiftUI

/// Asks the window to lay itself out again after something moved it.
///
/// A window resized while its space was not on screen — by a tiling manager,
/// or by the space being switched away from and back — came back with the old
/// layout still drawn: the pane's right edge cut off, the bar running past the
/// window. The window itself has the new size, so nothing in SwiftUI has a
/// reason to re-measure. These are the moments where that happens, and all
/// this does is mark the content dirty so the next frame is drawn to the size
/// the window actually is.
struct WindowRefresh: NSViewRepresentable {
    func makeNSView(context: Context) -> Watcher { Watcher() }

    func updateNSView(_ view: Watcher, context: Context) {}

    final class Watcher: NSView {
        private var observers: [(NotificationCenter, NSObjectProtocol)] = []

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach { $0.0.removeObserver($0.1) }
            observers = []
            guard let window else { return }
            configure(window)

            let workspace = NSWorkspace.shared.notificationCenter
            observe(workspace, NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            for name: NSNotification.Name in [
                NSWindow.didChangeScreenNotification,
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didBecomeKeyNotification
            ] {
                observe(NotificationCenter.default, name, object: window)
            }
        }

        private func observe(
            _ centre: NotificationCenter, _ name: NSNotification.Name, object: Any?
        ) {
            let token = centre.addObserver(forName: name, object: object, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append((centre, token))
        }

        /// The window paints its own ground behind the content, and the
        /// default is black. Resized from outside the app — by a tiling
        /// manager, or by a space being rearranged — the new area is that
        /// ground until SwiftUI has drawn into it, which read as the whole
        /// window going black for a moment. Painting it in the pane's own
        /// colour makes the gap invisible rather than making it shorter.
        private func configure(_ window: NSWindow) {
            window.backgroundColor = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
                    : NSColor(srgbRed: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF4 / 255, alpha: 1)
            }
            // Redraw the layer as the view resizes rather than stretching the
            // last frame over the new size.
            window.contentView?.wantsLayer = true
            window.contentView?.layerContentsRedrawPolicy = .duringViewResize
        }

        private func refresh() {
            guard let window, window.isVisible, let content = window.contentView else { return }
            content.needsLayout = true
            content.needsDisplay = true
            window.displayIfNeeded()
        }
    }
}
