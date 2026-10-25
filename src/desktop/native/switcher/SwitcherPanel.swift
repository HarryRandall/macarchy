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
    private var closing: Task<Void, Never>?
    private var closeWhenOpened = false
    /// Why the last action failed, until an opening shows it.
    private var failure: SwitcherFailure?
    private let log = Logger(subsystem: "io.github.harryrandall.macarchy", category: "switcher")

    /// What applying a theme or background does. Tests replace it, because the
    /// real one sets the wallpaper and appearance for the whole session.
    var actions = ThemeActions.live

    /// Orders the panel in. Tests replace it, so a reopened page can be
    /// checked without a window appearing on screen.
    var orderIn: @MainActor (NSWindow) -> Void = { $0.makeKeyAndOrderFront(nil) }
    /// Orders the panel out, and whether it is on screen: replaced in tests
    /// with `orderIn`, so a closing can run without a window appearing.
    var orderOut: @MainActor (NSWindow) -> Void = { $0.orderOut(nil) }
    var onScreen: @MainActor (NSWindow) -> Bool = { $0.isVisible }
    /// Under Reduce Motion the panel only fades; tests set it either way.
    var reduceMotion: @MainActor () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Counts fades, so one that a later fade replaced cannot touch the panel
    /// when it ends.
    private var fade = 0
    /// Resumes whoever awaits the running fade; a replaced fade resumes at once.
    private var fadeWaiter: CheckedContinuation<Void, Never>?

    /// Quicker than the settings window's motion: the panel is summoned by a
    /// shortcut and typed into at once, and leaves as soon as a theme is chosen.
    static let fadeIn: TimeInterval = 0.18
    static let fadeOut: TimeInterval = 0.12
    /// Where the arrival's scale-up starts.
    static let summonScale: CGFloat = 0.97

    /// Whether ⌘⌃Space was already taken when the app tried to register it;
    /// the system's Emoji & Symbols shortcut uses the same keys unless it is
    /// turned off. Setup health shows this.
    var hotKeyTaken: Bool { hotKey.map { !$0.isRegistered } ?? false }

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
            ) { notification in
                guard AppNotice.isForThisCopy(notification) else { return }
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

    var isVisible: Bool { panel.map(onScreen) ?? false }

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
        } else if isVisible, closing == nil {
            close()
        } else {
            // Closed, or fading out: `show` finishes the close at once.
            Task { await show() }
        }
    }

    /// Orders the panel in fully transparent, hands the page fresh state, and
    /// reveals it once that state has been drawn. WebKit stops drawing pages
    /// in windows that are off screen, so the render has to happen in a
    /// window that is ordered in, just not yet visible.
    func show() async {
        // A close still fading out finishes now, so the new opening starts
        // from a hidden panel rather than waiting for the fade.
        if closing != nil { endFade() }
        await closing?.value
        guard let model, !opening else { return }
        if isVisible {
            // Opened again while an action ran: show its failure in place.
            if let error = takeFailure() {
                await surface?.deliver(.switcherWillOpen(model.switcherState(), error: error))
            }
            return
        }
        opening = true
        closeWhenOpened = false
        let started = ContinuousClock.now
        // Opens on the catalogue already loaded; `themes.changed` brings in
        // anything the read finds. Reading first held the panel back.
        Task { await model.themes.reloadInBackground() }
        let (window, surface) = prepare(model)
        await SwitcherBackground.load(model.themes.themes)
        await surface.waitUntilReady(timeout: .seconds(1))
        position(window)
        setAlpha(of: window, to: 0)
        orderIn(window)
        window.makeFirstResponder(surface.webView)
        await surface.deliver(.switcherWillOpen(model.switcherState(), error: takeFailure()))
        reveal(window)
        opening = false
        log.notice("switcher shown in \(started.duration(to: .now), privacy: .public)")
        if closeWhenOpened {
            close()
        } else if failure != nil {
            // Another action failed while this opening was still drawing.
            await show()
        }
    }

    /// Fades the panel out, dropping input meanwhile so a second Return
    /// cannot apply again from a panel on its way out.
    func close() {
        guard let panel, onScreen(panel), closing == nil else { return }
        panel.isDismissing = true
        closing = Task {
            await fade(panel, to: 0, over: Self.fadeOut, .easeIn)
            // Also ends a fade that an opening cut short.
            setAlpha(of: panel, to: 0)
            // Reset the page while it can still draw, so the next opening
            // never starts from the previous one's frame.
            await surface?.deliver(.switcherDidClose, timeout: .milliseconds(150))
            // Ordering out resigns key, which calls `close()`; still closing,
            // that call does nothing.
            orderOut(panel)
            panel.isDismissing = false
            setAlpha(of: panel, to: 1)
            closing = nil
        }
    }

    /// Fades the panel in and, unless Reduce Motion is on, grows it slightly
    /// into place. Not awaited: a close during it replaces the fade.
    private func reveal(_ window: SwitcherWindow) {
        window.contentView?.layer?.removeAnimation(forKey: Self.summonKey)
        if !reduceMotion(), let view = window.contentView {
            view.wantsLayer = true
            // Layer-backed views anchor at their corner, so the scale is
            // taken about the middle by hand.
            let middle = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let scale = Self.summonScale
            var start = CATransform3DMakeTranslation(-middle.x, -middle.y, 0)
            start = CATransform3DConcat(start, CATransform3DMakeScale(scale, scale, 1))
            start = CATransform3DConcat(start, CATransform3DMakeTranslation(middle.x, middle.y, 0))
            let summon = CABasicAnimation(keyPath: "transform")
            summon.fromValue = NSValue(caTransform3D: start)
            summon.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            summon.duration = Self.fadeIn
            summon.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.layer?.add(summon, forKey: Self.summonKey)
        }
        Task {
            await fade(window, to: 1, over: Self.fadeIn, .easeOut)
            // The shadow was taken while the panel was transparent and smaller.
            window.invalidateShadow()
        }
    }

    static let summonKey = "summon"

    /// Runs one fade, replacing any still running, and returns when it ends
    /// or is itself replaced.
    private func fade(
        _ window: NSWindow, to alpha: CGFloat, over duration: TimeInterval,
        _ timing: CAMediaTimingFunctionName
    ) async {
        fade += 1
        let current = fade
        fadeWaiter?.resume()
        fadeWaiter = nil
        await withCheckedContinuation { continuation in
            fadeWaiter = continuation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: timing)
                window.animator().alphaValue = alpha
            } completionHandler: {
                MainActor.assumeIsolated {
                    guard self.fade == current else { return }
                    window.alphaValue = alpha
                    self.fadeWaiter?.resume()
                    self.fadeWaiter = nil
                }
            }
        }
    }

    /// A jump rather than a fade. It replaces a running fade, whose animation
    /// would otherwise go on setting the alpha.
    private func setAlpha(of window: NSWindow, to alpha: CGFloat) {
        endFade()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = alpha
        }
        window.alphaValue = alpha
    }

    /// Lets whoever awaits the running fade go on at once.
    private func endFade() {
        fade += 1
        fadeWaiter?.resume()
        fadeWaiter = nil
    }

    private func takeFailure() -> SwitcherFailure? {
        defer { failure = nil }
        return failure
    }

    /// Closes the panel, then runs a desktop-changing action. The panel goes
    /// first: the action redraws the desktop, and the panel should not sit
    /// over it while that happens. A failure reopens it with the reason on top.
    ///
    /// `closing` is false for an action that leaves the desktop as it is, such
    /// as choosing a background for a theme that is not applied: the panel
    /// stays, and the page says what changed.
    func perform(
        _ title: String, _ model: AppModel, closing: Bool = true,
        _ action: @MainActor () async -> CommandResult
    ) async throws {
        if closing { close() }
        let result = await action()
        model.log.record(result)
        await model.themes.reloadInBackground()
        guard !result.ok else { return }
        let summary = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason =
            summary.isEmpty ? "\(result.command) exited with status \(result.status)." : summary
        failure = SwitcherFailure(title: title, reason: reason)
        await show()
        throw BridgeFailure(.operationFailed, reason)
    }

    private func prepare(_ model: AppModel) -> (SwitcherWindow, WebSurface) {
        if let panel, let surface { return (panel, surface) }
        let surface = WebSurface(surface: .switcher, transparent: true, keepsDrawingInactive: true)
        surface.scheme.resolveMedia = { url in AppScheme.themeImage(for: url) }
        registerMethods(on: surface, model: model)

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
