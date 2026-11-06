import AppKit
import Foundation
import Testing
import WebKit

@testable import App

// Pictures of pages for reviewing the interface by eye, written only when
// `MACARCHY_UI_SNAPSHOTS` names a folder. Pages render in windows far off
// screen that are never ordered in, and `takeSnapshot` asks WebKit to draw
// the page, so nothing appears on the desktop.

/// Where snapshots go, or nil to skip snapshot suites.
let snapshotFolder = ProcessInfo.processInfo.environment["MACARCHY_UI_SNAPSHOTS"]
    .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }

/// The ground the switcher's native backdrop gives it: a dark HUD material
/// with nothing behind it. The page itself is transparent.
let switcherBacking = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)

/// Transitions and animations do not advance in a page whose window is not
/// on screen, so a snapshot would catch them at their first frame: a menu
/// still transparent, a sidebar still full width. Snapshots show end states.
/// Takes effect from the next load.
@MainActor
func settleMotion(_ webView: WKWebView) {
    webView.configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
                const style = document.createElement("style");
                style.textContent = "*, *::before, *::after { transition: none !important; animation: none !important; }";
                document.documentElement.append(style);
                """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
}

/// Moves `webView` into a borderless window of `size`, far off screen and
/// never ordered in. Keep the window alive while snapshotting.
@MainActor
func host(_ webView: WKWebView, size: CGSize, appearance: NSAppearance.Name) -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(origin: offscreenOrigin, size: size),
        styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: appearance)
    webView.removeFromSuperview()
    webView.frame = NSRect(origin: .zero, size: size)
    window.contentView?.addSubview(webView)
    return window
}

/// Writes what the page draws to `<folder>/<name>.png`, over `backing` when
/// the page is transparent.
@MainActor
func save(_ surface: WebSurface, _ name: String, backing: NSColor? = nil) async throws {
    let folder = try #require(snapshotFolder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    // Let layout, fonts and image decoding settle; animation frames may not
    // run in a window that is not on screen.
    // swiftlint:disable:next no_fixed_sleep_in_tests - a picture for review, not an assertion; WebKit has no settled event to await.
    try await Task.sleep(for: .milliseconds(400))

    let configuration = WKSnapshotConfiguration()
    configuration.afterScreenUpdates = true
    let image = try await surface.webView.takeSnapshot(configuration: configuration)
    var rect = CGRect(origin: .zero, size: image.size)
    let cgImage = try #require(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
    let width = cgImage.width
    let height = cgImage.height
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    if let backing {
        context.setFillColor(backing.cgColor)
        context.fill(bounds)
    }
    context.draw(cgImage, in: bounds)
    let output = try #require(context.makeImage())
    let data = try #require(
        NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]))
    try data.write(to: folder.appending(path: "\(name).png"))
}

/// The settings page, still and hosted off screen at the window's size.
@MainActor
func settingsShot(
    _ harness: Harness, appearance: NSAppearance.Name = .darkAqua
) throws -> (NSWindow, WebSurface) {
    let (_, surface) = try harness.settingsPage()
    // Collapsing the sidebar would save the choice in this process's
    // defaults, which every later test would then start from.
    surface.router.register("shell.setPreferences") { (_: ShellPreferences) in Null() }
    settleMotion(surface.webView)
    surface.load()
    let window = host(surface.webView, size: SettingsWindow.defaultSize, appearance: appearance)
    return (window, surface)
}

/// The switcher page, still and hosted off screen, opened with the current
/// theme selected.
@MainActor
func switcherShot(_ harness: Harness) async throws -> (NSWindow, WebSurface) {
    let (_, surface) = try harness.switcherPage(recorder: ThemeRecorder())
    settleMotion(surface.webView)
    surface.load()
    let window = host(surface.webView, size: ThemeSwitcher.size, appearance: .darkAqua)
    try await waitFor(surface, "the theme list", "return page.rows().length > 0;")
    await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
    try await waitFor(
        surface, "the current theme selected",
        "return !!page.selectedRow() && page.selectedRow() === page.activeRow();")
    return (window, surface)
}
