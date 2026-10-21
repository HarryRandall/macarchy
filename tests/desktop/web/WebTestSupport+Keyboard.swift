import AppKit
import Foundation
import Testing

@testable import App

// Keys sent as real `NSEvent`s through AppKit, so WebKit's own key handling,
// text input and key equivalents run, as they do for a person's keystrokes.
//
// Nothing is ordered in. A window that is not ordered in still dispatches
// events to its first responder, but it cannot become key: the test process
// may not activate, and making a non-activating panel key would take typing
// from whatever app the person is using. So `NSApp.sendEvent(_:)`, which
// routes to the key window, drops these events, and `press` repeats what it
// does instead: key equivalents to the window, then to the main menu, then
// the key-down to the window.

/// A window that tells WebKit it is key, so the page is focused and matches
/// `:focus` and `:focus-visible`. Only this process is told; the person's
/// key window does not change.
final class ReportsKeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
}

/// A key, as the keyboard sends it.
struct Key {
    let characters: String
    let keyCode: UInt16
    var flags: NSEvent.ModifierFlags = []

    static let tab = Key(characters: "\t", keyCode: 48)
    static let enter = Key(characters: "\r", keyCode: 36)
    static let escape = Key(characters: "\u{1B}", keyCode: 53)
    static let left = arrow(NSLeftArrowFunctionKey, 123)
    static let right = arrow(NSRightArrowFunctionKey, 124)
    static let down = arrow(NSDownArrowFunctionKey, 125)
    static let up = arrow(NSUpArrowFunctionKey, 126)

    /// Arrow keys send a function-key character from the private use area.
    private static func arrow(_ scalar: Int, _ keyCode: UInt16) -> Key {
        Key(
            characters: String(utf16CodeUnits: [unichar(scalar)], count: 1), keyCode: keyCode,
            flags: [.function, .numericPad])
    }

    /// ANSI key codes for the letters the tests type.
    private static let letters: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
        "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, "n": 45, "m": 46
    ]

    /// A lower-case letter key. Any other character is a mistake in the test.
    static func letter(_ character: Character) -> Key {
        guard let keyCode = letters[character] else {
            preconditionFailure("No key code for \"\(character)\"; add it to Key.letters.")
        }
        return Key(characters: String(character), keyCode: keyCode)
    }

    static func command(_ character: Character) -> Key {
        var key = letter(character)
        key.flags = .command
        return key
    }

    func with(_ flags: NSEvent.ModifierFlags) -> Key {
        Key(characters: characters, keyCode: keyCode, flags: self.flags.union(flags))
    }
}

/// Sends one key press to `window` the way `NSApplication.sendEvent(_:)`
/// would if the window were key.
@MainActor
func press(_ key: Key, in window: NSWindow) throws {
    func event(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: key.flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: key.characters,
                charactersIgnoringModifiers: key.characters, isARepeat: false,
                keyCode: key.keyCode))
    }
    let down = try event(.keyDown)
    if key.flags.contains(.command) {
        if window.performKeyEquivalent(with: down) { return }
        if NSApp.mainMenu?.performKeyEquivalent(with: down) == true { return }
    }
    window.sendEvent(down)
    window.sendEvent(try event(.keyUp))
}

/// Presses the letter key for each character of `text`.
@MainActor
func typeText(_ text: String, in window: NSWindow) throws {
    for character in text { try press(.letter(character), in: window) }
}

/// Stands in for the app's main menu: Search… on ⌘K, as `SettingsApp`
/// declares it, and the standard Edit menu's Paste on ⌘V. Each records
/// instead of acting, so nothing reads the general pasteboard. Call
/// `restore()` when done.
@MainActor
final class MenuRecorder: NSObject {
    var searches = 0
    var pastes = 0
    private let previous = NSApp.mainMenu

    override init() {
        super.init()
        let menu = NSMenu()
        for (title, items) in [
            ("Edit", [("Paste", #selector(paste(_:)), "v")]),
            ("View", [("Search…", #selector(search(_:)), "k")])
        ] {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            for (name, action, key) in items {
                let item = NSMenuItem(title: name, action: action, keyEquivalent: key)
                item.target = self
                submenu.addItem(item)
            }
            top.submenu = submenu
            menu.addItem(top)
        }
        NSApp.mainMenu = menu
    }

    func restore() { NSApp.mainMenu = previous }

    @objc func paste(_ sender: Any?) { pastes += 1 }
    @objc func search(_ sender: Any?) { searches += 1 }
}

// MARK: - Off-screen hosting

/// Far enough off every screen that nothing could show, even if ordered in.
let offscreenOrigin = CGPoint(x: -20000, y: -20000)

/// The settings page's web view, moved into a borderless window far off
/// screen that is never ordered in, and focused as if the window were key.
@MainActor
func offscreenSettings(_ harness: Harness, pane: Pane = .layout) throws -> (NSWindow, WebSurface) {
    let (_, surface) = try harness.settingsPage(pane: pane)
    let window = ReportsKeyWindow(
        contentRect: NSRect(origin: offscreenOrigin, size: SettingsWindow.defaultSize),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    surface.webView.removeFromSuperview()
    surface.webView.frame = try #require(window.contentView).bounds
    window.contentView?.addSubview(surface.webView)
    window.makeFirstResponder(surface.webView)
    // WebKit updates the page's focus when it hears the window became key.
    NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
    return (window, surface)
}

/// The switcher in its own panel, moved far off screen and never ordered in,
/// with the web view first responder as `ThemeSwitcher.show()` leaves it.
@MainActor
struct OffscreenSwitcher {
    let switcher: ThemeSwitcher
    let panel: SwitcherWindow
    let surface: WebSurface

    init(_ harness: Harness, recorder: ThemeRecorder) throws {
        (switcher, surface) = try harness.switcherPage(recorder: recorder)
        panel = try #require(switcher.panel)
        panel.setFrameOrigin(offscreenOrigin)
        panel.makeFirstResponder(surface.webView)
        #expect(!panel.isVisible)
    }
}
