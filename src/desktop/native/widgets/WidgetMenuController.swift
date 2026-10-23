import AppKit
import Macarchy
import SwiftUI

/// Opens a widget's dropdown under its item when `macarchy widget click`
/// asks, and closes it on a click anywhere else.
///
/// The panel never becomes the key window and the app is never activated,
/// so the window being worked in keeps its focus and its border.
@MainActor
final class WidgetMenuController {
    static let shared = WidgetMenuController()

    private let model = WidgetMenuModel()
    private var panel: NSPanel?
    private var openID: String?
    /// The widget whose dropdown a click outside just closed, and when. The
    /// same click reaches the bar and asks to open it again, which it ignores.
    private var lastClosed: (id: String, at: Date)?
    private var monitors: [Any] = []
    /// Where each widget's item was last seen, so a dropdown opens without
    /// waiting to ask SketchyBar. Checked again after it opens.
    private var frames: [String: NSRect] = [:]
    private var refresher: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private var host: WidgetHost { WidgetHostController.shared.host }

    func start() {
        guard observers.isEmpty else { return }
        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: WidgetActions.dropdownNotification, object: nil, queue: .main
            ) { notification in
                let id = notification.userInfo?["instance"] as? String
                MainActor.assumeIsolated {
                    if let id { WidgetMenuController.shared.toggle(id) }
                }
            })
        // Changing Space, or another app coming forward, means the person
        // has moved on, as a click elsewhere does.
        for name in [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification
        ] {
            observers.append(
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: name, object: nil, queue: .main
                ) { _ in
                    MainActor.assumeIsolated { WidgetMenuController.shared.close(byClick: true) }
                })
        }
        model.pick = { [weak self] row, option in self?.pick(row, option: option) }
        _ = makePanel()
        Task { await warmFrames() }
    }

    /// Learns where every widget sits, so the first dropdown opens quickly too.
    private func warmFrames() async {
        await host.reload()
        for instance in await host.instances {
            if let frame = await Self.frame(of: instance.id) { frames[instance.id] = frame }
        }
    }

    func toggle(_ id: String) {
        if openID == id { return close() }
        if let lastClosed, lastClosed.id == id, Date().timeIntervalSince(lastClosed.at) < 0.8 {
            return
        }
        Task { await open(id) }
    }

    private func open(_ id: String) async {
        guard let items = await host.menu(for: id), !items.isEmpty else { return }
        let cached = frames[id]
        var found = cached
        if found == nil { found = await Self.frame(of: id) }
        guard let item = found else { return }
        close()
        model.items = items
        let panel = panel ?? makePanel()
        place(panel, under: item)
        panel.orderFrontRegardless()
        openID = id
        watchClicks(outside: panel)
        if cached != nil {
            // The bar may have moved since; follow it if so.
            if let current = await Self.frame(of: id), current != item, openID == id {
                frames[id] = current
                place(panel, under: current)
            }
        } else {
            frames[id] = item
        }
        // Readings such as a clock keep moving while the dropdown is open.
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let items = await self.host.menu(for: id) else { return }
                self.model.items = items
            }
        }
    }

    func close(byClick: Bool = false) {
        if let openID, byClick { lastClosed = (openID, Date()) }
        openID = nil
        refresher?.cancel()
        refresher = nil
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        panel?.orderOut(nil)
    }

    private func place(_ panel: NSPanel, under item: NSRect) {
        let size = panel.contentView?.fittingSize ?? .zero
        panel.setFrame(Self.placement(of: size, under: item), display: true)
    }

    /// Closes on a click anywhere but the dropdown: in another app, on the
    /// desktop, or in one of Macarchy's own windows.
    private func watchClicks(outside panel: NSPanel) {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: mask,
            handler: { _ in
                MainActor.assumeIsolated { WidgetMenuController.shared.close(byClick: true) }
            })
        {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: mask,
            handler: { event in
                MainActor.assumeIsolated {
                    if event.window !== WidgetMenuController.shared.panel {
                        WidgetMenuController.shared.close(byClick: true)
                    }
                }
                return event
            })
        {
            monitors.append(local)
        }
    }

    private func pick(_ row: Int, option: String?) {
        guard let id = openID else { return }
        Task {
            do {
                switch try await host.pick(row, option: option, in: id) {
                case .open, .run: close()
                case .set:
                    if let items = await host.menu(for: id) { model.items = items }
                case .nothing: break
                }
            } catch {
                NSSound.beep()
                close()
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = WidgetMenuPanel()
        let content = FirstMouseHostingView(rootView: WidgetMenuView(model: model))
        content.sizingOptions = [.intrinsicContentSize]
        panel.contentView = content
        self.panel = panel
        return panel
    }

    // MARK: - Placement

    /// Where SketchyBar drew the widget's item, in screen coordinates.
    private static func frame(of id: String) async -> NSRect? {
        let result = await Integrations().sketchybar(["--query", id])
        guard result.ok, let data = result.stdout.data(using: .utf8),
            let item = try? JSONDecoder().decode(QueriedItem.self, from: data),
            let (display, rect) = item.boundingRects.min(by: { $0.key < $1.key })
        else { return nil }
        let number = Int(display.split(separator: "-").last ?? "") ?? 1
        let screens = NSScreen.screens
        let screen = screens.indices.contains(number - 1) ? screens[number - 1] : NSScreen.main
        guard let screen, rect.origin.count == 2, rect.size.count == 2 else { return nil }
        // SketchyBar measures from the top-left of its display.
        return NSRect(
            x: screen.frame.minX + rect.origin[0],
            y: screen.frame.maxY - rect.origin[1] - rect.size[1],
            width: rect.size[0], height: rect.size[1])
    }

    /// Just under the item, lined up with its left edge, or its right edge
    /// when it sits in the right half, and kept on the screen.
    private static func placement(of size: NSSize, under item: NSRect) -> NSRect {
        let screen =
            NSScreen.screens.first { $0.frame.contains(NSPoint(x: item.midX, y: item.midY)) }
            ?? NSScreen.main
        let bounds = screen?.frame ?? item
        var x = item.midX > bounds.midX ? item.maxX - size.width : item.minX
        x = min(max(x, bounds.minX + 8), bounds.maxX - size.width - 8)
        return NSRect(x: x, y: item.minY - 6 - size.height, width: size.width, height: size.height)
    }

    private struct QueriedItem: Decodable {
        struct Rect: Decodable {
            let origin: [Double]
            let size: [Double]
        }
        let boundingRects: [String: Rect]

        enum CodingKeys: String, CodingKey { case boundingRects = "bounding_rects" }
    }
}

/// A borderless panel that floats over everything and never takes focus.
private final class WidgetMenuPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes the first click, which a window that is not key would otherwise
/// spend on becoming key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
