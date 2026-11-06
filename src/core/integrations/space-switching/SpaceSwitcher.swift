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
/// The Dock carries a swipe out in its own order of Spaces, which yabai's
/// scripting addition can leave behind when it swaps or moves Spaces: the
/// window server, yabai and Mission Control show the new order while the
/// Dock still swipes through the old one. So each switch is watched as it
/// lands. A swipe that shows a Space off the way to the target, or settles
/// short of it, is put right through yabai, which goes by index, and later
/// switches go through yabai until that Dock restarts.
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

    /// The focused window, as yabai reports it.
    public struct Window: Equatable, Sendable {
        public var id: Int
        public var app: String
        /// The index of the Space it is on.
        public var space: Int

        public init(id: Int, app: String, space: Int) {
            self.id = id
            self.app = app
            self.space = space
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
        var focusedWindow: @Sendable () async -> Window?
        /// Moves a window to the Space with that index; false when yabai refused.
        var moveWindow: @Sendable (_ window: Int, _ space: Int) async -> Bool
        /// Told a window has moved, so the bar can show it on its new Space
        /// straight away instead of waiting to read yabai again.
        var windowMoved: @Sendable (_ window: Window, _ space: Int) async -> Void = { _, _ in }
        var focusWindow: @Sendable (Int) async -> Void
        /// A short wait between looks at whether a switch has landed.
        var pause: @Sendable () async -> Void
        /// Which Dock is running, by process id, so swipes are tried again
        /// once a Dock whose order was wrong restarts.
        var dock: @Sendable () -> Int? = { nil }
        /// The index of the focused Space, as yabai reports it.
        var focusedSpace: @Sendable () async -> Int? = { nil }
        /// Every window a desktop swap carries: not sticky, minimised or
        /// hidden. Nil when yabai cannot be asked.
        var windows: @Sendable () async -> [PlacedWindow]? = { nil }
        var toggleFloat: @Sendable (_ window: Int) async -> Void = { _ in }
        /// Swaps two tiled windows' places on their Space.
        var swapWindows: @Sendable (Int, Int) async -> Void = { _, _ in }
    }

    let desktop: Desktop
    /// Pauses before a switch that has not landed is given up on, as for
    /// one Mission Control swallowed.
    private let patience: Int

    /// The Space last asked for and not yet started.
    var wanted: Int?
    /// The window to focus once `wanted` shows, when it came from a move.
    var follow: Int?
    /// The Space a switch has been sent to and not yet landed on.
    var heading: Int?
    var tickets = 0
    /// The ticket of the latest request applied; older ones finishing late
    /// are ignored.
    var newest = 0
    var switching = false
    /// Set when a swipe landed where the window server's order said it
    /// would not, with the Dock it happened under.
    private var misorderedDock: Int??

    /// Whether switches go through yabai because the Dock's order of
    /// Spaces was found to differ from the window server's.
    func swipesDistrusted() -> Bool {
        guard let dock = misorderedDock else { return false }
        if dock == desktop.dock() { return true }
        misorderedDock = nil
        return false
    }

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

    /// Switches one Space left or right on the pointer's display, as a
    /// trackpad swipe does, from where switching is heading: two quick swipes
    /// go two Spaces. At either end nothing happens.
    public func step(_ direction: Direction) async {
        guard let layout = await desktop.layout() else { return }
        let ids = layout.pointerDisplay
        let showing = desktop.showing()
        let pending = [wanted, heading].compactMap { $0 }.compactMap { layout.ids[$0] }
        guard
            let from = pending.compactMap(ids.firstIndex(of:)).first
                ?? ids.firstIndex(where: showing.contains)
        else { return }
        let to = direction == .right ? from + 1 : from - 1
        guard ids.indices.contains(to),
            let index = layout.ids.first(where: { $0.value == ids[to] })?.key
        else { return }
        await request(index, moving: false)
    }

    private func request(_ index: Int, moving: Bool) async {
        tickets += 1
        let ticket = tickets
        var window: Int?
        if moving, let focused = await desktop.focusedWindow(),
            await desktop.moveWindow(focused.id, index)
        {
            window = focused.id
            if focused.space != index { await desktop.windowMoved(focused, index) }
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

    func run() async {
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
                heading = index
                let arrived = await switchTo(index, id: id, layout: layout)
                heading = nil
                guard arrived else { continue }
            }
            if let window, wanted == nil {
                await desktop.focusWindow(window)
            }
        }
    }

    /// Switches to Space `index` and waits for it to show. Returns whether
    /// it did.
    func switchTo(_ index: Int, id: Int, layout: Layout) async -> Bool {
        if let way = swipe(id: id, layout: layout) {
            switch await watch(id: id, way: way, display: layout.pointerDisplay) {
            case .arrived:
                return true
            case .misplaced:
                // The Dock's order differs from the window server's.
                misorderedDock = .some(desktop.dock())
            case .stuck:
                break
            }
        }
        // yabai goes to the Space by index, so it is safe after any swipe.
        await desktop.yabaiFocus(index)
        return await watch(id: id, way: nil) == .arrived
    }

    /// Sends the swipes to Space `id` on the pointer's display. Returns the
    /// Spaces they should pass through, from the one showing to `id`, or
    /// nil when yabai has to switch instead.
    private func swipe(id: Int, layout: Layout) -> [Int]? {
        let showing = desktop.showing()
        guard !swipesDistrusted(), desktop.gesturesAllowed(), !desktop.overlayOpen(),
            let target = layout.pointerDisplay.firstIndex(of: id),
            let current = layout.pointerDisplay.firstIndex(where: showing.contains),
            desktop.swipe(target > current ? .right : .left, abs(target - current))
        else { return nil }
        return Array(layout.pointerDisplay[min(current, target)...max(current, target)])
    }

    private enum Landing { case arrived, misplaced, stuck }

    /// Waits for Space `id` to show. With the `way` swipes should pass
    /// along `display`, showing a Space off it, or stopping short of `id`,
    /// is misplaced. Swipes still under way are let finish first, so they
    /// do not undo yabai's correction.
    private func watch(id: Int, way: [Int]?, display: [Int] = []) async -> Landing {
        let here = { self.desktop.showing().intersection(display) }
        let start = here()
        var strayed = false
        var still = 0
        var last = start
        for _ in 0..<patience {
            if desktop.showing().contains(id) { return .arrived }
            let now = here()
            if let way, !now.isEmpty, !now.contains(where: way.contains) { strayed = true }
            still = now == last ? still + 1 : 0
            last = now
            if strayed, still >= Self.settled { return .misplaced }
            await desktop.pause()
        }
        if desktop.showing().contains(id) { return .arrived }
        // Moved, but not all the way: the Dock went through other Spaces.
        return way != nil && (strayed || here() != start) ? .misplaced : .stuck
    }

    /// Looks a Space must stay showing before a stray swipe counts as done.
    static let settled = 15
}
