import AppKit
import Macarchy

/// The React settings window: an AppKit window around one web view.
///
/// The window stays hidden until the page has rendered real data, so it never
/// opens on an empty frame. It is kept, not released, when closed, so reopening
/// is immediate; the page is refreshed each time it comes forward instead.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()

    private(set) var surface: WebSurface?
    private var window: NSWindow?
    private var model: AppModel?
    private var presenting = false

    static let defaultSize = NSSize(width: 1000, height: 720)
    static let minimumSize = NSSize(width: 720, height: 600)
    /// Matches the page's top bar, so the window buttons sit on its centre line.
    static let barHeight: CGFloat = 44
    /// Room across the top-left corner for the close, minimise and zoom buttons.
    static let trafficLightGutter: CGFloat = 78

    func attach(_ model: AppModel) {
        self.model = model
    }

    var isVisible: Bool { window?.isVisible ?? false }

    /// Creates the window and loads its page without showing it.
    @discardableResult
    func preload() -> WebSurface? {
        guard let model else { return nil }
        return prepare(model).1
    }

    /// Brings the window forward, creating and loading it on first use. Before
    /// setup has run there are no settings to show, so the classic window,
    /// which runs setup, opens instead.
    func show(_ pane: Pane? = nil) {
        guard let model else { return }
        if let pane, Pane.migrated.contains(pane), pane != InterfacePreferences.selectedPane {
            InterfacePreferences.selectedPane = pane
            if let surface, surface.isReady { surface.send(.shellChanged(model.shellState())) }
        }
        if !FileManager.default.fileExists(atPath: model.settingsStore.url.path) {
            AppDelegate.showClassicWindow(pane: nil, show: nil)
            return
        }
        let (window, surface) = prepare(model)
        NSApp.setActivationPolicy(.regular)
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        guard !presenting else { return }
        presenting = true
        Task {
            await surface.waitUntilReady(timeout: .seconds(2))
            presenting = false
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(surface.webView)
            NSApp.activate()
        }
    }

    private func prepare(_ model: AppModel) -> (NSWindow, WebSurface) {
        if let window, let surface { return (window, surface) }
        let surface = WebSurface(surface: .settings)
        surface.scheme.resolveMedia = { [weak model] url in
            url.path() == "/wallpaper"
                ? model?.currentThemeWallpaper : AppScheme.themeImage(for: url)
        }
        // One line per feature the settings window shows.
        surface.router.registerShell(model: model, surface: surface)
        surface.router.registerLayout(model: model)
        surface.router.registerThemes(model: model)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: true)
        window.title = "Macarchy"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.contentMinSize = Self.minimumSize
        window.backgroundColor = Self.paneBackground
        window.delegate = self

        let content = NSView(frame: NSRect(origin: .zero, size: Self.defaultSize))
        surface.webView.frame = content.bounds
        surface.webView.autoresizingMask = [.width, .height]
        content.addSubview(surface.webView)
        let lights = TrafficLights.Host(
            frame: NSRect(
                x: 0, y: content.bounds.height - Self.barHeight, width: Self.trafficLightGutter,
                height: Self.barHeight))
        lights.leading = 20
        lights.autoresizingMask = [.minYMargin, .maxXMargin]
        content.addSubview(lights)
        window.contentView = content

        if !window.setFrameUsingName("MacarchySettings") { window.center() }
        window.setFrameAutosaveName("MacarchySettings")

        self.window = window
        self.surface = surface
        surface.load()
        return (window, surface)
    }

    /// The window paints its own ground before the page has drawn, and while
    /// a tiling manager resizes it. Matching the page's colour keeps both
    /// moments invisible.
    private static let paneBackground = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
            : NSColor(srgbRed: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF4 / 255, alpha: 1)
    }

    // MARK: - Window

    /// Coming forward is when something else may have changed the desktop:
    /// a daemon restarted, the CLI ran, the classic window edited a setting.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let model, let surface, surface.isReady else { return }
        surface.send(.shellChanged(model.shellState()))
        Task {
            if let snapshot = await model.refreshLayout() {
                surface.send(.layoutChanged(model.layoutState(snapshot)))
            }
        }
    }
}
