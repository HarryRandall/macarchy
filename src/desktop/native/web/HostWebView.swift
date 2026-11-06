import AppKit
import WebKit

/// A web view that behaves like window chrome where the page says it is.
///
/// WebKit on macOS has no drag regions, so the page reports its title bar's
/// height and the rects of the controls inside it. A mouse-down in the bar but
/// outside every control moves the window, and a double-click does what the
/// person chose in Desktop & Dock, as a native title bar would.
final class HostWebView: WKWebView {
    var titlebarHeight: CGFloat = 0
    /// In page coordinates: points from the top-left of the view.
    var titlebarControls: [CGRect] = []

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard isTitlebarDrag(event), let window else { return super.mouseDown(with: event) }
        if event.clickCount == 2 {
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window.performMiniaturize(nil)
            case "None": break
            default: window.performZoom(nil)
            }
        } else {
            window.performDrag(with: event)
        }
    }

    private func isTitlebarDrag(_ event: NSEvent) -> Bool {
        guard titlebarHeight > 0 else { return false }
        let local = convert(event.locationInWindow, from: nil)
        let point = CGPoint(x: local.x, y: isFlipped ? local.y : bounds.height - local.y)
        guard point.y >= 0, point.y < titlebarHeight else { return false }
        return !titlebarControls.contains { $0.contains(point) }
    }

    /// Keeps editing and inspection, drops browser navigation such as Reload
    /// and Back, which would only ever break the interface.
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let kept: Set<String> = [
            "WKMenuItemIdentifierCopy", "WKMenuItemIdentifierCut", "WKMenuItemIdentifierPaste",
            "WKMenuItemIdentifierSelectAll", "WKMenuItemIdentifierInspectElement",
            "WKMenuItemIdentifierSpellingMenu", "WKMenuItemIdentifierLookUp"
        ]
        for item in menu.items.reversed() {
            guard let identifier = item.identifier?.rawValue else { continue }
            if identifier.hasPrefix("WKMenuItemIdentifier"), !kept.contains(identifier) {
                menu.removeItem(item)
            }
        }
        while menu.items.first?.isSeparatorItem == true { menu.removeItem(at: 0) }
        while menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
    }
}
