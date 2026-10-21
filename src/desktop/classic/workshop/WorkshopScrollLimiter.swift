import AppKit
import SwiftUI

/// Limits large wheel and trackpad deltas only inside the detail viewport.
struct WorkshopScrollLimiter: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollRegion { ScrollRegion() }

    func updateNSView(_ view: ScrollRegion, context: Context) {}

    static func dismantleNSView(_ view: ScrollRegion, coordinator: ()) {
        view.stopMonitoring()
    }

    final class ScrollRegion: NSView {
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            let handler: (NSEvent) -> NSEvent? = { [weak self] event in
                var result = event
                MainActor.assumeIsolated { result = self?.limited(event) ?? event }
                return result
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: handler)
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func limited(_ event: NSEvent) -> NSEvent {
            guard let window, event.window === window,
                !isHiddenOrHasHiddenAncestor,
                bounds.contains(convert(event.locationInWindow, from: nil))
            else { return event }

            let delta = abs(event.scrollingDeltaY)
            // Leave normal scrolling and its momentum untouched. A rate cap
            // tied to event timing made high-frequency trackpads crawl.
            guard event.momentumPhase.isEmpty else { return event }
            let limit: CGFloat = event.hasPreciseScrollingDeltas ? 80 : 8
            guard delta > limit, let copied = event.cgEvent?.copy() else { return event }
            let scale = Double(limit / delta)
            // Scale all representations together, keeping direction, scroll
            // phase and momentum intact for the native scroll view.
            for field: CGEventField in [
                .scrollWheelEventDeltaAxis1,
                .scrollWheelEventFixedPtDeltaAxis1,
                .scrollWheelEventPointDeltaAxis1
            ] {
                copied.setDoubleValueField(field, value: copied.getDoubleValueField(field) * scale)
            }
            return NSEvent(cgEvent: copied) ?? event
        }
    }
}
