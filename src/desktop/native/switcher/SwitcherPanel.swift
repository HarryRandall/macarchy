import AppKit
import Macarchy
import OSLog

/// The floating theme switcher, opened with ⌘⌃Space from anywhere.
///
/// A non-activating panel takes typing without bringing Macarchy's main
/// window forward or switching Spaces, the way Raycast and Spotlight do.
/// Losing focus closes it.
///
/// Its page is loaded once, at launch, and kept: opening hands it fresh state
/// and waits for it to render before the panel is ordered in, so the first
/// frame on screen is always the current one.
@MainActor
final class ThemeSwitcher {
    static let shared = ThemeSwitcher()

    private(set) var panel: SwitcherWindow?
    private(set) var surface: WebSurface?
    private var model: AppModel?
    private var hotKey: HotKey?
    private var opening = false
    private var closing = false
    private var closeWhenOpened = false
    private let log = Logger(subsystem: "io.github.harryrandall.macarchy", category: "switcher")

    /// What applying a theme or background does. Tests replace it, because the
    /// real one sets the wallpaper and appearance for the whole session.
    var actions = ThemeActions.live

    /// Whether ⌘⌃Space was free to register; the system's Emoji & Symbols
    /// shortcut uses the same keys unless it is turned off.
    var hotKeyAvailable: Bool { hotKey?.isRegistered ?? false }

    /// Posted by `macarchy switcher`, so any shortcut tool can open the panel.
    static let openNotification = Notification.Name("io.github.harryrandall.macarchy.switcher")

    static let size = CGSize(width: 750, height: 474)
    static let cornerRadius: CGFloat = 12

    func attach(_ model: AppModel, registerShortcut: Bool = true) {
        self.model = model
        if registerShortcut, !Self.shortcutDisabledForDevelopment {
            hotKey = HotKey.themeSwitcher { [weak self] in self?.toggle() }
            DistributedNotificationCenter.default().addObserver(
                forName: Self.openNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { ThemeSwitcher.shared.toggle() }
            }
            Logger(subsystem: "io.github.harryrandall.macarchy", category: "switcher").notice(
                "Cmd-Ctrl-Space registered: \(self.hotKey?.isRegistered == true, privacy: .public)")
            if hotKey?.isRegistered == false {
                model.log.failure(
                    "theme switcher shortcut unavailable",
                    "⌘⌃Space is taken, usually by Emoji & Symbols in Keyboard Shortcuts.")
            }
        }
        _ = prepare(model)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Carbon lets two processes register the same hotkey, so a development
    /// copy running beside the installed app would open its panel too.
    private static var shortcutDisabledForDevelopment: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["MACARCHY_DEBUG_NO_SHORTCUT"] == "1"
        #else
        false
        #endif
    }

    func toggle() {
        if opening {
            closeWhenOpened = true
        } else if isVisible {
            close()
        } else {
            Task { await show() }
        }
    }

    /// Orders the panel in fully transparent, hands the page fresh state, and
    /// reveals it once that state has been drawn. WebKit stops drawing pages
    /// in windows that are off screen, so the render has to happen in a
    /// window that is ordered in, just not yet visible.
    func show() async {
        guard let model, !opening, !isVisible else { return }
        opening = true
        closeWhenOpened = false
        let started = ContinuousClock.now
        model.themes.reload()
        let (window, surface) = prepare(model)
        await surface.waitUntilReady(timeout: .seconds(1))
        position(window)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(surface.webView)
        await surface.deliver(.switcherWillOpen(model.switcherState()))
        window.alphaValue = 1
        opening = false
        log.notice("switcher shown in \(started.duration(to: .now), privacy: .public)")
        if closeWhenOpened { close() }
    }

    func close() {
        guard let panel, panel.isVisible, !closing else { return }
        closing = true
        // Reset the page while it can still draw, so the next opening never
        // starts from the previous one's frame.
        panel.alphaValue = 0
        Task {
            await surface?.deliver(.switcherDidClose, timeout: .milliseconds(150))
            panel.orderOut(nil)
            panel.alphaValue = 1
            closing = false
        }
    }

    private func prepare(_ model: AppModel) -> (SwitcherWindow, WebSurface) {
        if let panel, let surface { return (panel, surface) }
        let surface = WebSurface(surface: .switcher, transparent: true, keepsDrawingInactive: true)
        surface.scheme.resolveMedia = { url in AppScheme.themeImage(for: url) }
        register(surface, model)

        let window = SwitcherWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.onResign = { [weak self] in self?.close() }

        // The blurred HUD ground has to be native: CSS can only blur what the
        // page itself draws. The page draws everything above it.
        let backdrop = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.appearance = NSAppearance(named: .darkAqua)
        backdrop.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        backdrop.autoresizingMask = [.width, .height]
        surface.webView.frame = backdrop.bounds
        surface.webView.autoresizingMask = [.width, .height]
        backdrop.addSubview(surface.webView)
        window.contentView = backdrop

        panel = window
        self.surface = surface
        surface.load()
        return (window, surface)
    }

    private func register(_ surface: WebSurface, _ model: AppModel) {
        let router = surface.router
        router.register("switcher.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return model.switcherState()
        }
        router.register("switcher.refresh") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            model.themes.reload()
            return model.switcherState()
        }
        router.register("switcher.close") { [weak self] (_: Empty) in
            self?.close()
            return Null()
        }
        router.register("switcher.openSettings") { [weak self] (_: Empty) in
            self?.close()
            SettingsWindow.shared.show()
            return Null()
        }
        // The panel goes first: applying redraws the desktop, and the panel
        // should not sit over it while that happens.
        router.register("switcher.applyTheme") { [weak self, weak model] (params: ThemeParams) in
            guard let model, model.themes.themes.contains(where: { $0.name == params.theme }) else {
                throw BridgeFailure(.invalidParams, "There is no theme named \(params.theme).")
            }
            self?.close()
            let apply = self?.actions.apply ?? ThemeActions.live.apply
            Task {
                model.log.record(await apply(model, params.theme))
                model.themes.reload()
            }
            return Null()
        }
        router.register("switcher.useBackground") {
            [weak self, weak model] (params: BackgroundParams) in
            guard let model,
                let theme = model.themes.themes.first(where: { $0.name == params.theme }),
                SwitcherBackground.all(in: theme).contains(where: { $0.relativePath == params.path }
                )
            else { throw BridgeFailure(.invalidParams, "That background is not in this theme.") }
            self?.close()
            let choose = self?.actions.useBackground ?? ThemeActions.live.useBackground
            Task {
                model.log.record(await choose(model, params.theme, params.path))
                model.themes.reload()
            }
            return Null()
        }
    }

    /// Centred horizontally, a little above the middle, on the screen with the pointer.
    private func position(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let origin = CGPoint(
            x: frame.midX - Self.size.width / 2,
            y: frame.minY + frame.height * 0.62 - Self.size.height / 2)
        window.setFrame(CGRect(origin: origin, size: Self.size), display: true)
    }

    /// A stretchable rounded-rect mask. Visual effect views ignore a layer's
    /// corner radius for the blur itself, so the shape has to be a mask.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// The switcher's two desktop-changing actions.
struct ThemeActions {
    var apply: @MainActor (AppModel, String) async -> CommandResult
    var useBackground: @MainActor (AppModel, String, String) async -> CommandResult

    static var live: ThemeActions {
        ThemeActions(
            apply: { model, name in
                await ThemeApplication(integrations: model.backend).apply(name: name)
            },
            useBackground: { model, name, path in
                await ThemeApplication(integrations: model.backend).chooseWallpaper(
                    theme: name, path: path)
            })
    }
}

/// Borderless panels refuse key status by default, which would stop typing.
final class SwitcherWindow: NSPanel {
    var onResign: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func resignKey() {
        super.resignKey()
        onResign?()
    }
}
