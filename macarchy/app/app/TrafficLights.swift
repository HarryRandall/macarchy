import AppKit
import SwiftUI

/// Moves the window's close, minimise and zoom buttons into the app's own bar.
///
/// The window hides its title bar, which leaves those buttons pinned to the
/// very top-left while the bar's contents sit a few points lower — the two
/// rows never line up. Firefox and Safari solve this the same way: keep the
/// system buttons, and place them on the row the app actually draws.
///
/// The buttons are adopted as subviews of this view rather than nudged inside
/// the system's title bar. AppKit re-lays its title bar out on every resize,
/// so a button left in there snapped back to the top-left and was pushed down
/// again a frame later — which read as the lights jittering while the window
/// was dragged. Owned here, they simply move with the bar.
///
/// Every step is optional. If AppKit ever stops handing back the buttons this
/// does nothing and the window keeps its default placement rather than ending
/// up with no way to close it.
struct TrafficLights: NSViewRepresentable {
    /// Distance from the window's leading edge to the first button.
    var leading: CGFloat = 18

    func makeNSView(context: Context) -> Host {
        let view = Host()
        view.leading = leading
        return view
    }

    func updateNSView(_ view: Host, context: Context) {
        view.leading = leading
        view.needsLayout = true
    }

    final class Host: NSView {
        /// Distance from this view's leading edge to the first button. The
        /// view starts at the window's leading edge, so the two agree.
        var leading: CGFloat = 18
        /// The system's own gap between one button and the next.
        private static let gap: CGFloat = 6

        private var mouseInside = false
        private var observers: [NSObjectProtocol] = []
        private var placing = false
        private var needsAnotherPass = false

        /// Clicks land on the buttons; everything else falls through to the
        /// bar underneath, which is draggable.
        override func hitTest(_ point: NSPoint) -> NSView? {
            let hit = super.hitTest(point)
            return hit === self ? nil : hit
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Leaving the window drops the watchers; they are the only thing
            // held here, and each closure holds `self` weakly.
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            adopt()
            // AppKit re-places these buttons on its own schedule and does not
            // always report it as a frame change — the zoom button in
            // particular came back to the system's own inset, low and tight
            // against its neighbour. The window posts an update at the end of
            // every event loop it draws in, which is the one moment that is
            // reliably after whatever AppKit has just done. Checking three
            // frames there costs nothing and cannot be missed.
            // `didUpdate` runs at the end of an event loop the window drew
            // in; `didResize` runs as the window is being resized. The zoom
            // button is re-placed by AppKit on both, and a resize is where it
            // showed: it slid down and across for the length of the drag
            // before the next update put it back.
            for name: NSNotification.Name in [
                NSWindow.didUpdateNotification,
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didExitFullScreenNotification
            ] {
                observers.append(
                    NotificationCenter.default.addObserver(
                        forName: name, object: window, queue: nil
                    ) { [weak self] _ in
                        MainActor.assumeIsolated { self?.place() }
                    })
            }
        }

        override func viewDidEndLiveResize() {
            super.viewDidEndLiveResize()
            place()
        }

        private var windowButtons: [NSButton] {
            guard let window else { return [] }
            return [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
                .compactMap { window.standardWindowButton($0) }
        }

        /// Takes the three buttons over. AppKit hands them back to its own
        /// title bar after a full-screen transition, so this is re-run from
        /// `layout()` rather than done once.
        private func adopt() {
            let buttons = windowButtons
            guard buttons.count == 3 else { return }
            for button in buttons where button.superview !== self {
                button.removeFromSuperview()
                addSubview(button)
                // AppKit keeps laying the buttons out to its own title bar's
                // measurements even after they have moved here, which left
                // them sitting low in the bar. Watching each frame lets the
                // placement be restored in the same pass, so nothing shows.
                button.postsFrameChangedNotifications = true
                observers.append(
                    NotificationCenter.default.addObserver(
                        forName: NSView.frameDidChangeNotification, object: button,
                        queue: nil
                    ) { [weak self] _ in
                        MainActor.assumeIsolated { self?.place() }
                    })
            }
        }

        /// Puts the row where it belongs: inset from the leading edge, centred
        /// on the bar.
        ///
        /// AppKit lays its own title bar out one button at a time, and it can
        /// move a button that this pass has already placed — which left the
        /// zoom button sitting low. A change arriving mid-pass asks for
        /// another one instead of being dropped as re-entrant.
        private func place() {
            guard !placing else {
                needsAnotherPass = true
                return
            }
            placing = true
            defer { placing = false }
            var passes = 0
            repeat {
                needsAnotherPass = false
                applyFrames()
                passes += 1
            } while needsAnotherPass && passes < 4
        }

        private func applyFrames() {
            // The step comes from the buttons themselves. AppKit does not
            // always hand back 14 pt circles — they come back larger on a
            // smaller window — and a fixed step then overlapped them.
            var x = leading
            for button in windowButtons where button.superview === self {
                button.postsFrameChangedNotifications = true
                let origin = NSPoint(
                    x: x, y: ((bounds.height - button.frame.height) / 2).rounded())
                if button.frame.origin != origin { button.setFrameOrigin(origin) }
                x += button.frame.width + Self.gap
            }
        }

        override func layout() {
            super.layout()
            adopt()
            place()
        }

        // MARK: - Hover

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(
                NSTrackingArea(
                    rect: bounds,
                    options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                    owner: self))
        }

        override func mouseEntered(with event: NSEvent) { setMouseInside(true) }
        override func mouseExited(with event: NSEvent) { setMouseInside(false) }

        private func setMouseInside(_ inside: Bool) {
            guard mouseInside != inside else { return }
            mouseInside = inside
            windowButtons.forEach { $0.needsDisplay = true }
        }

        /// A window button asks its superview whether the pointer is anywhere
        /// over the group before drawing its glyph. In the system title bar
        /// that is AppKit's own view; here it is this one.
        @objc func _mouseInGroup(_ button: NSButton) -> Bool { mouseInside }
    }
}
