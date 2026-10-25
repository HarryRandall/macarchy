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
    /// The widget whose dropdown a click on its own box just closed. The
    /// bar passes the same click on a moment later, and that one is ignored.
    private var swallow: (id: String, at: Date)?
    private var monitors: [Any] = []
    /// Where each widget's item was last seen, so a dropdown opens without
    /// waiting to ask SketchyBar. Checked again after it opens.
    private var frames: [String: NSRect] = [:]
    /// Each widget's box and its usual background, so a click turns it grey
    /// at once.
    private var boxes: [String: WidgetBox] = [:]
    private var refresher: Task<Void, Never>?
    /// The latest click asking for a dropdown; an earlier one still looking
    /// up its rows gives way to it.
    private var request = 0
    /// The widget whose box is grey, and the box with its usual background.
    private var highlighted: (id: String, box: WidgetBox)?
    /// Highlighting and putting back, one after the other, so a quick close
    /// cannot leave a widget grey.
    private var highlighting: Task<Void, Never>?
    static let highlightColour = "0x33ffffff"
    private var observers: [NSObjectProtocol] = []

    private var host: WidgetHost { WidgetHostController.shared.host }

    func start() {
        guard observers.isEmpty else { return }
        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: WidgetActions.dropdownNotification, object: nil, queue: .main
            ) { notification in
                guard AppNotice.isForThisCopy(notification) else { return }
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
                    MainActor.assumeIsolated { WidgetMenuController.shared.close() }
                })
        }
        model.pick = { [weak self] row, option in self?.pick(row, option: option) }
        _ = makePanel()
        Task { await warmFrames() }
    }

    /// Learns where every widget sits, so the first dropdown opens quickly too.
    private func warmFrames() async {
        await host.reload()
        await learnFrames()
    }

    /// Where every widget sits now, for opening under it and for telling a
    /// click on a widget from a click elsewhere. Hidden ones are skipped.
    private func learnFrames() async {
        for instance in await host.instances {
            guard let box = await WidgetBox.find(instance.id) else { continue }
            if let frame = box.frame { frames[instance.id] = frame }
            // A box read while grey, even one being put back, would be learnt
            // as its usual look and then put back grey.
            if highlighted?.id != instance.id && box.background.colour != Self.highlightColour {
                boxes[instance.id] = box
            }
        }
    }

    func toggle(_ id: String) {
        if let swallow, swallow.id == id, Date().timeIntervalSince(swallow.at) < 2 {
            self.swallow = nil
            return
        }
        swallow = nil
        if openID == id { return close() }
        request += 1
        let request = request
        // Grey first, before the rows are worked out, so the click shows at once.
        queue { await $0.highlight(id) }
        Task { await open(id, request: request) }
    }

    private func open(_ id: String, request: Int) async {
        let items = await host.menu(for: id) ?? []
        let cached = frames[id]
        var found = cached
        if found == nil && !items.isEmpty { found = await WidgetBox.find(id)?.frame }
        guard request == self.request else { return }
        guard let item = found, !items.isEmpty else {
            // Nothing to show after all, so the box goes back.
            return queue { await $0.unhighlight() }
        }
        hide()
        model.items = items
        let panel = panel ?? makePanel()
        place(panel, under: item)
        panel.orderFrontRegardless()
        openID = id
        watchClicks(outside: panel)
        if cached != nil {
            // The bar may have moved since; follow it if so.
            if let current = await WidgetBox.find(id)?.frame, current != item, openID == id {
                frames[id] = current
                place(panel, under: current)
            }
        } else {
            frames[id] = item
        }
        // Another dropdown may have opened while this one looked for its
        // item; its refresher must be the only one, or the two widgets'
        // rows would take turns in the panel.
        guard openID == id else { return }
        refresher?.cancel()
        Task { await learnFrames() }
        // Readings such as a clock keep moving while the dropdown is open.
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.openID == id, let items = await self.host.menu(for: id),
                    self.openID == id
                else { return }
                self.model.items = items
            }
        }
    }

    func close() {
        // A dropdown still being worked out should not appear after this.
        request += 1
        queue { await $0.unhighlight() }
        hide()
    }

    /// Takes the dropdown away, leaving the grey box to whoever comes next.
    private func hide() {
        openID = nil
        refresher?.cancel()
        refresher = nil
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        panel?.orderOut(nil)
        model.pointer = nil
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
                MainActor.assumeIsolated {
                    WidgetMenuController.shared.clicked(at: NSEvent.mouseLocation)
                }
            })
        {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
            matching: mask,
            handler: { event in
                MainActor.assumeIsolated {
                    if event.window !== WidgetMenuController.shared.panel {
                        WidgetMenuController.shared.close()
                    }
                }
                return event
            })
        {
            monitors.append(local)
        }
    }

    /// A click in another app or on the bar while a dropdown is open. On
    /// the open widget it closes the dropdown at once; on another widget it
    /// leaves the dropdown for the bar's click to switch, so nothing flashes;
    /// anywhere else it closes.
    private func clicked(at point: NSPoint) {
        guard let openID else { return }
        if let hit = frames.first(where: { $0.value.contains(point) })?.key {
            guard hit == openID else { return }
            close()
            swallow = (hit, Date())
            return
        }
        close()
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
        content.pointerMoved = { [weak self] point in self?.model.pointer = point }
        panel.contentView = content
        self.panel = panel
        return panel
    }

    // MARK: - Placement

    private func queue(_ step: @escaping @MainActor (WidgetMenuController) async -> Void) {
        let previous = highlighting
        highlighting = Task { [weak self] in
            await previous?.value
            if let self { await step(self) }
        }
    }

    /// Draws the widget's box grey, as a menu bar item looks while its menu
    /// is open, and puts back any other.
    private func highlight(_ id: String) async {
        guard highlighted?.id != id else { return }
        await unhighlight()
        var box = boxes[id]
        if box == nil { box = await WidgetBox.find(id) }
        guard var box else { return }
        if box.background.colour == Self.highlightColour {
            // Read while grey, so its usual look is not known: no box.
            box = WidgetBox(
                name: box.name, frame: box.frame,
                background: .init(drawing: box.background.drawing, colour: "0x00000000"))
        }
        boxes[id] = box
        highlighted = (id, box)
        await WidgetBox.paint(box.name, .init(drawing: "on", colour: Self.highlightColour))
    }

    private func unhighlight() async {
        guard let (_, box) = highlighted else { return }
        highlighted = nil
        await WidgetBox.paint(box.name, box.background)
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
        acceptsMouseMovedEvents = true
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes the first click, which a window that is not key would otherwise
/// spend on becoming key, and tracks the pointer itself, since hover only
/// reaches SwiftUI in the key window.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var pointerMoved: (CGPoint?) -> Void = { _ in }
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        report(event)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        report(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        pointerMoved(nil)
    }

    private func report(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pointerMoved(CGPoint(x: point.x, y: isFlipped ? point.y : bounds.height - point.y))
    }
}
