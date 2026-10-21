import AppKit
import Foundation
import Testing

@testable import App

/// Records how every focusable element looks at rest, so a focused one can
/// be checked for a visible change: a ring, a shadow or a border colour, on
/// the element or the two boxes around it.
private let focusBaseline = """
    const signature = (element) => [element, element.parentElement, element.parentElement?.parentElement]
      .filter(Boolean).map((node) => {
        const style = getComputedStyle(node);
        return [style.outlineStyle, style.outlineWidth, style.outlineColor, style.boxShadow,
          style.borderTopColor, style.backgroundColor].join(" ");
      }).join(" / ");
    window.__focus = { signature, baseline: new WeakMap(), last: document.activeElement };
    for (const element of document.querySelectorAll("button, input, select, a[href], [tabindex]")) {
      window.__focus.baseline.set(element, signature(element));
    }
    """

/// What has focus once it has moved, or null while it has not.
private let focusReport = """
    const element = document.activeElement;
    if (element === window.__focus.last) return null;
    const label = element.getAttribute("aria-label")
      || [...(element.labels ?? [])].map((l) => l.textContent.trim()).join(" ")
      || element.textContent.trim();
    const baseline = window.__focus.baseline.get(element);
    return JSON.stringify({
      label, tag: element.tagName, type: element.type ?? "",
      main: !!element.closest("main"),
      focusVisible: element.matches(":focus-visible"),
      shown: baseline !== undefined && window.__focus.signature(element) !== baseline,
    });
    """

/// The focused element, as `focused(_:)` reports it.
struct Focus: Decodable, CustomStringConvertible {
    let label: String
    let tag: String
    let type: String
    /// Inside the page's `main`, rather than the sidebar or top bar.
    let main: Bool
    let focusVisible: Bool
    /// Looks different from how it looked at rest.
    let shown: Bool

    var description: String { "\(tag.lowercased())[\(type)] \"\(label)\"" }
}

/// Records how focusable elements look at rest. Call once the page has
/// rendered and before the first `focused(_:)`.
@MainActor
func recordFocusBaseline(_ surface: WebSurface) async throws {
    try await run(surface, focusBaseline)
}

/// Makes the next `focused(_:)` report the current element even though
/// focus has not moved.
@MainActor
func forgetLastFocus(_ surface: WebSurface) async throws {
    try await run(surface, "window.__focus.last = null;")
}

/// Waits for focus to move after a key press, then for its style to settle,
/// since WebKit handles keys in the page's process after `press` returns.
@MainActor
func focused(_ surface: WebSurface) async throws -> Focus {
    let deadline = ContinuousClock.now + .seconds(2)
    var focus: Focus?
    while ContinuousClock.now < deadline {
        if let json = try await run(surface, focusReport) as? String {
            focus = try JSONDecoder().decode(Focus.self, from: Data(json.utf8))
            if focus?.shown == true || focus?.tag == "BODY" { break }
        } else if focus != nil {
            break
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    try await run(surface, "window.__focus.last = document.activeElement;")
    guard let focus else { throw PageTimeout(description: "focus did not move") }
    return focus
}

/// Presses `key` until focus leaves the page, and returns each stop.
@MainActor
func tabCycle(_ key: Key, in window: NSWindow, _ surface: WebSurface) async throws -> [Focus] {
    var stops: [Focus] = []
    for _ in 0..<80 {
        try press(key, in: window)
        let focus = try await focused(surface)
        if focus.tag == "BODY" {
            if stops.isEmpty { continue }
            return stops
        }
        stops.append(focus)
    }
    Issue.record("focus never left the page: \(stops)")
    return stops
}

/// Presses ⌥Tab, which reaches every control, until the control labelled
/// `label`, of `type` when given, has focus. Returns false if it never does.
@MainActor
func tabTo(
    _ label: String, type: String? = nil, in window: NSWindow, _ surface: WebSurface
) async throws -> Bool {
    for _ in 0..<80 {
        try press(Key.tab.with(.option), in: window)
        let focus = try await focused(surface)
        if focus.label == label, type == nil || focus.type == type { return true }
    }
    return false
}
