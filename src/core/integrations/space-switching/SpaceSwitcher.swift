import Foundation

/// Switches Spaces one at a time, always on to the latest Space asked for.
///
/// A switch is a fast Dock swipe (`SpaceGesture`), which skips the slide, on
/// the display under the pointer. A switch to another display, while Mission
/// Control or App Exposé is open, or without permission to post events goes
/// through yabai instead, which slides.
///
/// Presses made while a switch is landing only record their Space. When it
/// lands, the switcher goes on to the last one asked for and skips the ones
/// in between, so a burst never overshoots: macOS 27 can leave the Dock black
/// if more swipes are sent than there are Spaces. Each switch is worked out
/// from the Space showing once the last one landed, never from the window
/// server mid-swipe, which reports the Spaces passed on the way.
///
/// Requests are taken in the order they arrive. Moving a window to a Space
/// asks yabai first; a press made while that is under way wins, so the
/// window still moves but the switch goes where the later press asked.
public actor SpaceSwitcher {
    public enum Direction: Sendable { case left, right }

    /// Where Spaces are, from the window server.
    public struct Layout: Equatable, Sendable {
        /// Space ids by index, numbered as yabai does.
        public var ids: [Int: Int]
        /// The ids on the display under the pointer, left to right: the
        /// Spaces a swipe moves along.
        public var pointerDisplay: [Int]

        public init(ids: [Int: Int], pointerDisplay: [Int]) {
            self.ids = ids
            self.pointerDisplay = pointerDisplay
        }
    }

    /// Everything that reads or changes the desktop, so tests use fakes.
    public struct Desktop: Sendable {
        var layout: @Sendable () async -> Layout?
        /// The ids of the Spaces showing now, which change once a switch lands.
        var showing: @Sendable () -> Set<Int>
        /// Whether this process may post events.
        var gesturesAllowed: @Sendable () -> Bool
        var overlayOpen: @Sendable () -> Bool
        /// Sends that many swipes; false when they could not all be made.
        var swipe: @Sendable (Direction, Int) -> Bool
        var yabaiFocus: @Sendable (Int) async -> Void
        var focusedWindow: @Sendable () async -> Int?
        /// Moves a window to the Space with that index; false when yabai refused.
        var moveWindow: @Sendable (_ window: Int, _ space: Int) async -> Bool
        var focusWindow: @Sendable (Int) async -> Void
        /// A short wait between looks at whether a switch has landed.
        var pause: @Sendable () async -> Void
    }

    private let desktop: Desktop
    /// Pauses before a switch that has not landed is given up on, as for
    /// one Mission Control swallowed.
    private let patience: Int

    /// The Space last asked for and not yet started.
    private var wanted: Int?
    /// The window to focus once `wanted` shows, when it came from a move.
    private var follow: Int?
    private var tickets = 0
    /// The ticket of the latest request applied; older ones finishing late
    /// are ignored.
    private var newest = 0
    private var switching = false

    public init(desktop: Desktop, patience: Int = 150) {
        self.desktop = desktop
        self.patience = patience
    }

    /// Switches to Space `index`. Returns once it has landed, or at once when
    /// a switch already under way will go on to it.
    public func go(to index: Int) async {
        await request(index, moving: false)
    }

    /// Moves the focused window to Space `index` and follows it there,
    /// focusing it again on arrival. With no focused window the Space still
    /// changes.
    public func move(to index: Int) async {
        await request(index, moving: true)
    }

    private func request(_ index: Int, moving: Bool) async {
        tickets += 1
        let ticket = tickets
        var window: Int?
        if moving, let focused = await desktop.focusedWindow(),
            await desktop.moveWindow(focused, index)
        {
            window = focused
        }
        guard ticket > newest else { return }
        newest = ticket
        wanted = index
        follow = window
        guard !switching else { return }
        switching = true
        await run()
        switching = false
    }

    private func run() async {
        let layout = await desktop.layout()
        while let index = wanted {
            let window = follow
            wanted = nil
            follow = nil
            guard let layout else {
                // Without the window server's Spaces, yabai still knows them.
                await desktop.yabaiFocus(index)
                continue
            }
            // A Space that does not exist is left alone, as yabai does.
            guard let id = layout.ids[index] else { continue }
            if !desktop.showing().contains(id) {
                await send(index, id: id, layout: layout)
                guard await landed(on: id) else { continue }
            }
            if let window, wanted == nil {
                await desktop.focusWindow(window)
            }
        }
    }

    private func send(_ index: Int, id: Int, layout: Layout) async {
        let showing = desktop.showing()
        if desktop.gesturesAllowed(), !desktop.overlayOpen(),
            let target = layout.pointerDisplay.firstIndex(of: id),
            let current = layout.pointerDisplay.firstIndex(where: showing.contains),
            desktop.swipe(target > current ? .right : .left, abs(target - current))
        {
            return
        }
        // yabai goes to the Space by index, so it is safe after a partial swipe.
        await desktop.yabaiFocus(index)
    }

    private func landed(on id: Int) async -> Bool {
        for _ in 0..<patience {
            if desktop.showing().contains(id) { return true }
            await desktop.pause()
        }
        return desktop.showing().contains(id)
    }
}
