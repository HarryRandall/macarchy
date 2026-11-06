import Foundation

/// Swapping two desktops by swapping their windows.
///
/// Swapping the Spaces themselves, as yabai's scripting addition does,
/// reorders them behind the Dock's back: later swipes land on the wrong
/// desktop, and a second swap can put a desktop in the wrong place. Moving
/// the windows leaves every Space where it is.
///
/// Moving a tiled window into a desktop that has windows of its own splits
/// one of them, so the layout would come out mixed. Instead the desktop's
/// tiled windows float first, keeping their frames, and cross without
/// joining the other desktop's layout. The other desktop's windows then
/// tile into an empty one, and the floated windows tile again, in their
/// order, once they have arrived. Any window that still comes out of place
/// is swapped back into it.
extension SpaceSwitcher {
    /// A window as yabai lays it out.
    public struct PlacedWindow: Equatable, Sendable {
        public var id: Int
        public var app: String
        /// The index of its Space.
        public var space: Int
        public var floating: Bool
        public var focused: Bool
        /// Its top-left corner. Tiled windows read left to right, then top
        /// to bottom.
        public var x: Double
        public var y: Double

        public init(
            id: Int, app: String, space: Int, floating: Bool = false, focused: Bool = false,
            x: Double = 0, y: Double = 0
        ) {
            self.id = id
            self.app = app
            self.space = space
            self.floating = floating
            self.focused = focused
            self.x = x
            self.y = y
        }
    }

    /// Swaps the windows of the desktop showing with those of desktop
    /// `index`, then follows them there and focuses the window that had
    /// focus. A switch under way lands first. Nothing happens when `index`
    /// is showing or does not exist.
    public func swap(with index: Int) async {
        tickets += 1
        let ticket = tickets
        while switching { await desktop.pause() }
        switching = true
        let window = await swapWindows(with: index)
        newest = max(newest, ticket)
        // A press made during the swap goes on from here.
        if wanted != nil {
            await run()
        } else if let window {
            await desktop.focusWindow(window)
        }
        switching = false
    }

    /// Returns the window to focus afterwards, or nil when nothing moved.
    private func swapWindows(with index: Int) async -> Int? {
        let layout = await desktop.layout()
        guard let current = await showingIndex(layout), current != index,
            layout.map({ $0.ids[index] != nil }) ?? true,
            let all = await desktop.windows()
        else { return nil }
        let mine = Self.ordered(all.filter { $0.space == current })
        let theirs = Self.ordered(all.filter { $0.space == index })
        let tiled = mine.filter { !$0.floating }
        for window in tiled { await desktop.toggleFloat(window.id) }
        for window in mine { await carry(window, to: index) }
        await arrive(at: index, layout: layout)
        for window in theirs { await carry(window, to: current) }
        for window in tiled { await desktop.toggleFloat(window.id) }
        await putInOrder([
            index: tiled.map(\.id), current: theirs.filter { !$0.floating }.map(\.id)
        ])
        return (mine.first(where: \.focused) ?? tiled.first ?? mine.first)?.id
    }

    /// The desktop showing on the pointer's display, or the one yabai says
    /// has focus.
    private func showingIndex(_ layout: Layout?) async -> Int? {
        if let layout {
            let showing = desktop.showing().intersection(layout.pointerDisplay)
            if let match = layout.ids.first(where: { showing.contains($0.value) }) {
                return match.key
            }
        }
        return await desktop.focusedSpace()
    }

    private func carry(_ window: PlacedWindow, to space: Int) async {
        guard await desktop.moveWindow(window.id, space) else { return }
        await desktop.windowMoved(
            Window(id: window.id, app: window.app, space: window.space), space)
    }

    private func arrive(at index: Int, layout: Layout?) async {
        guard let layout, let id = layout.ids[index] else {
            await desktop.yabaiFocus(index)
            return
        }
        guard !desktop.showing().contains(id) else { return }
        heading = index
        _ = await switchTo(index, id: id, layout: layout)
        heading = nil
    }

    /// Swaps tiled windows until each Space reads in the `order` given.
    private func putInOrder(_ order: [Int: [Int]]) async {
        guard order.values.contains(where: { $0.count > 1 }),
            let after = await desktop.windows()
        else { return }
        for (space, wanted) in order where wanted.count > 1 {
            var actual = Self.ordered(after.filter { $0.space == space && !$0.floating }).map(\.id)
            guard Set(actual) == Set(wanted) else { continue }
            for position in wanted.indices where actual[position] != wanted[position] {
                guard let other = actual.firstIndex(of: wanted[position]) else { continue }
                await desktop.swapWindows(actual[position], wanted[position])
                actual.swapAt(position, other)
            }
        }
    }

    /// Tiled windows left to right, then top to bottom, then floating ones.
    static func ordered(_ windows: [PlacedWindow]) -> [PlacedWindow] {
        windows.sorted {
            ($0.floating ? 1 : 0, $0.x, $0.y, $0.id) < ($1.floating ? 1 : 0, $1.x, $1.y, $1.id)
        }
    }
}
