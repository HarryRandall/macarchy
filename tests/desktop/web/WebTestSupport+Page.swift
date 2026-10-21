import Foundation
import Testing
import WebKit

@testable import App

/// Small DOM helpers every script gets as `page`, so tests read as what a
/// person does. Keep these generic; a helper only one page needs belongs in
/// that page's suite, prepended to its scripts.
let prelude = """
    const page = {
      text: () => document.body.innerText,
      setValue(element, value) {
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
        setter.call(element, String(value));
        element.dispatchEvent(new Event("input", { bubbles: true }));
        element.dispatchEvent(new Event("change", { bubbles: true }));
      },
      key(element, key, options = {}) {
        element.dispatchEvent(
          new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options }));
      },
      range(label) {
        return [...document.querySelectorAll("input[type=range]")]
          .find((input) => [...input.labels].some((l) => l.textContent.trim() === label));
      },
      number(label) { return document.querySelector(`input[aria-label="${label} in pt"]`); },
      toggle(label) { return document.querySelector(`[role=switch][aria-label="${label}"]`); },
      select(label) { return document.querySelector(`[aria-label="${label}"]`); },
      card(title) {
        return [...document.querySelectorAll('[role=group][aria-label="Choose your layout"] button')]
          .find((button) => [...button.querySelectorAll("span")]
            .some((span) => span.childElementCount === 0 && span.textContent.trim() === title));
      },
      disabled(element) {
        return element.disabled === true || element.getAttribute("aria-disabled") === "true"
          || element.hasAttribute("data-disabled");
      },
      search() { return document.querySelector("input[role=combobox]"); },
      rows() { return [...document.querySelectorAll('[role=listbox][aria-label="Themes"] [role=option]')]; },
      selectedRow() { return this.rows().find((row) => row.getAttribute("aria-selected") === "true"); },
      activeRow() {
        return this.rows().find((row) => [...row.querySelectorAll("span")]
          .some((span) => span.textContent === "active"));
      },
    };

    """

struct PageTimeout: Error, CustomStringConvertible {
    let description: String
}

/// Runs `body` as an async function in the page, after the prelude, and
/// returns what it returns.
@MainActor
@discardableResult
func run(_ surface: WebSurface, _ body: String) async throws -> Any? {
    try await surface.webView.callAsyncJavaScript(prelude + body, contentWorld: .page)
}

/// Polls a script until it returns true. Animation frames may not run in a
/// window that is not on screen, so pages are never waited on through
/// `app.ready`, only through what they render.
@MainActor
func waitFor(
    _ surface: WebSurface, _ what: String, timeout: Duration = .seconds(8), _ body: String
) async throws {
    let deadline = ContinuousClock.now + timeout
    var lastError = ""
    while ContinuousClock.now < deadline {
        do {
            if try await run(surface, "try { \(body) } catch (e) { return false }") as? Bool == true
            {
                return
            }
        } catch { lastError = " (last error: \(error.localizedDescription))" }
        try await Task.sleep(for: .milliseconds(50))
    }
    let text = (try? await run(surface, "return page.text()") as? String) ?? "<unreadable>"
    throw PageTimeout(
        description: "Timed out waiting for \(what)\(lastError). The page shows:\n\(text)")
}

/// Polls a native condition, such as a fake's calls or a saved file.
@MainActor
func waitUntil(
    _ what: String, timeout: Duration = .seconds(5), _ condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw PageTimeout(description: "Timed out waiting for \(what)")
}

/// A script's result as a string, or empty.
func string(_ value: Any?) -> String { value as? String ?? "" }
