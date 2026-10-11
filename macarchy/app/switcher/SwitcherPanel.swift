import AppKit
import OSLog
import SwiftUI

/// The floating theme switcher, opened with ⌘⌃Space from anywhere.
///
/// A non-activating panel takes typing without bringing Macarchy's main
/// window forward or switching Spaces, the way Raycast and Spotlight do.
/// Losing focus closes it.
@MainActor
final class ThemeSwitcher {
    static let shared = ThemeSwitcher()

    private var panel: SwitcherWindow?
    private var model: AppModel?
    private var hotKey: HotKey?

    /// Whether ⌘⌃Space was free to register; the system's Emoji & Symbols
    /// shortcut uses the same keys unless it is turned off.
    var hotKeyAvailable: Bool { hotKey?.isRegistered ?? false }

    /// Posted by `macarchy switcher`, so any shortcut tool can open the panel.
    static let openNotification = Notification.Name("io.github.harryrandall.macarchy.switcher")

    func attach(_ model: AppModel) {
        self.model = model
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

    func toggle() {
        if let panel, panel.isVisible { close() } else { show() }
    }

    func show() {
        guard let model else { return }
        model.themes.reload()
        let window = panel ?? makePanel(model)
        panel = window
        window.contentView = NSHostingView(
            rootView: ThemeSwitcherView(close: { [weak self] in self?.close() })
                .environment(model))
        position(window)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    private func makePanel(_ model: AppModel) -> SwitcherWindow {
        let window = SwitcherWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.size.width, height: Self.size.height),
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
        return window
    }

    static let size = CGSize(width: 750, height: 474)

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
