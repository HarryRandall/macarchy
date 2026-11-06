import Foundation
import Testing

@testable import Macarchy

/// Swapping desktops by swapping their windows, on a fake yabai that tiles
/// a window joining a layout in front of the ones there, so order only
/// survives if the swap puts it right.
struct SpaceSwapTests {
    enum Event: Equatable {
        /// A window moved to a Space, and whether it was floating then.
        case moved(Int, to: Int, floating: Bool)
        case swipe(SpaceSwitcher.Direction, Int)
        case yabai(Int)
        case swapped(Int, Int)
        case focused(Int)
    }

    /// Five Spaces, where Space n has id n * 10.
    final class Board: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Int
        /// Tiled windows of each Space, left to right.
        private var tiled: [Int: [Int]] = [:]
        private var floating: [Int: Int] = [:]
        private var focused: Int?
        private var log: [Event] = []
        /// Run when the first window moves, as a key pressed mid-swap.
        var duringSwap: (@Sendable () async -> Void)?

        init(on index: Int) { current = index }

        var space: Int { lock.withLock { current } }
        var events: [Event] { lock.withLock { log } }

        func tiled(on space: Int) -> [Int] { lock.withLock { tiled[space] ?? [] } }
        func floating(on space: Int) -> [Int] {
            lock.withLock { floating.filter { $0.value == space }.map(\.key).sorted() }
        }

        func tile(_ windows: [Int], on space: Int) {
            lock.withLock { tiled[space, default: []] += windows }
        }

        func float(_ window: Int, on space: Int) { lock.withLock { floating[window] = space } }

        func focus(_ window: Int) { lock.withLock { focused = window } }

        private func record(_ event: Event) { lock.withLock { log.append(event) } }

        private func spaceOf(_ window: Int) -> Int? {
            floating[window] ?? tiled.first { $0.value.contains(window) }?.key
        }

        func move(_ window: Int, to space: Int) async -> Bool {
            let hook: (@Sendable () async -> Void)? = lock.withLock {
                guard let from = spaceOf(window) else { return nil }
                let isFloating = floating[window] != nil
                log.append(.moved(window, to: space, floating: isFloating))
                if isFloating {
                    floating[window] = space
                } else {
                    tiled[from]?.removeAll { $0 == window }
                    tiled[space, default: []].insert(window, at: 0)
                }
                defer { duringSwap = nil }
                return duringSwap
            }
            await hook?()
            return true
        }

        func toggleFloat(_ window: Int) {
            lock.withLock {
                if let space = floating.removeValue(forKey: window) {
                    tiled[space, default: []].insert(window, at: 0)
                } else if let space = tiled.first(where: { $0.value.contains(window) })?.key {
                    tiled[space]?.removeAll { $0 == window }
                    floating[window] = space
                }
            }
        }

        func swapWindows(_ first: Int, _ second: Int) {
            lock.withLock {
                log.append(.swapped(first, second))
                for (space, order) in tiled {
                    if let a = order.firstIndex(of: first), let b = order.firstIndex(of: second) {
                        tiled[space]?.swapAt(a, b)
                    }
                }
            }
        }

        func windows() -> [SpaceSwitcher.PlacedWindow] {
            lock.withLock {
                tiled.flatMap { space, order in
                    order.enumerated().map {
                        SpaceSwitcher.PlacedWindow(
                            id: $0.element, app: "App", space: space,
                            focused: $0.element == focused,
                            x: Double($0.offset) * 100)
                    }
                }
                    + floating.map {
                        SpaceSwitcher.PlacedWindow(
                            id: $0.key, app: "App", space: $0.value, floating: true,
                            focused: $0.key == focused, x: 50, y: 50)
                    }
            }
        }

        func desktop() -> SpaceSwitcher.Desktop {
            SpaceSwitcher.Desktop(
                layout: {
                    SpaceSwitcher.Layout(
                        ids: Dictionary(uniqueKeysWithValues: (1...5).map { ($0, $0 * 10) }),
                        pointerDisplay: [10, 20, 30, 40, 50])
                },
                showing: { [self.space * 10] },
                gesturesAllowed: { true },
                overlayOpen: { false },
                swipe: { direction, steps in
                    self.record(.swipe(direction, steps))
                    self.lock.withLock { self.current += direction == .right ? steps : -steps }
                    return true
                },
                yabaiFocus: { index in
                    self.record(.yabai(index))
                    self.lock.withLock { self.current = index }
                },
                focusedWindow: { nil },
                moveWindow: { await self.move($0, to: $1) },
                focusWindow: { self.record(.focused($0)) },
                pause: {},
                focusedSpace: { self.space },
                windows: { self.windows() },
                toggleFloat: { self.toggleFloat($0) },
                swapWindows: { self.swapWindows($0, $1) })
        }
    }

    func swap(_ board: Board, with index: Int) async -> SpaceSwitcher {
        let switcher = SpaceSwitcher(desktop: board.desktop(), patience: 5)
        await switcher.swap(with: index)
        return switcher
    }

    @Test("each desktop's windows go to the other, and you follow yours there")
    func swapsAndFollows() async {
        let board = Board(on: 2)
        board.tile([1], on: 2)
        board.tile([2], on: 4)
        board.focus(1)
        _ = await swap(board, with: 4)
        #expect(board.tiled(on: 4) == [1])
        #expect(board.tiled(on: 2) == [2])
        #expect(board.space == 4)
        #expect(board.events.last == .focused(1))
    }

    @Test("tiled windows keep their left-to-right order on both desktops")
    func keepsOrder() async {
        let board = Board(on: 1)
        board.tile([1, 2], on: 1)
        board.tile([3, 4, 5], on: 3)
        board.focus(2)
        _ = await swap(board, with: 3)
        #expect(board.tiled(on: 3) == [1, 2])
        #expect(board.tiled(on: 1) == [3, 4, 5])
        #expect(board.events.last == .focused(2))
    }

    @Test("your tiled windows cross floating, so they never join the other desktop's layout")
    func crossesFloating() async {
        let board = Board(on: 1)
        board.tile([1, 2], on: 1)
        board.tile([3], on: 2)
        _ = await swap(board, with: 2)
        let crossings = board.events.compactMap { event -> Bool? in
            if case .moved(let window, _, let floating) = event, [1, 2].contains(window) {
                return floating
            }
            return nil
        }
        #expect(crossings == [true, true])
        #expect(board.floating(on: 2).isEmpty)
    }

    @Test("the other desktop's windows arrive after yours have left, once you are there")
    func ordersTheMoves() async {
        let board = Board(on: 1)
        board.tile([1], on: 1)
        board.tile([3], on: 3)
        _ = await swap(board, with: 3)
        #expect(
            Array(board.events.prefix(3)) == [
                .moved(1, to: 3, floating: true), .swipe(.right, 2),
                .moved(3, to: 1, floating: false)
            ])
    }

    @Test("floating windows stay floating")
    func keepsFloating() async {
        let board = Board(on: 1)
        board.tile([1], on: 1)
        board.float(9, on: 1)
        board.float(8, on: 2)
        _ = await swap(board, with: 2)
        #expect(board.floating(on: 2) == [9])
        #expect(board.floating(on: 1) == [8])
        #expect(board.tiled(on: 2) == [1])
    }

    @Test("an empty desktop swaps too, leaving this one empty")
    func emptyDesktop() async {
        let board = Board(on: 1)
        board.tile([1, 2], on: 1)
        _ = await swap(board, with: 5)
        #expect(board.tiled(on: 5) == [1, 2])
        #expect(board.tiled(on: 1).isEmpty)
        #expect(board.space == 5)
    }

    @Test("swapping with the desktop showing, or one that does not exist, does nothing")
    func nothingToSwap() async {
        let board = Board(on: 2)
        board.tile([1], on: 2)
        _ = await swap(board, with: 2)
        _ = await swap(board, with: 9)
        #expect(board.events.isEmpty)
        #expect(board.tiled(on: 2) == [1])
    }

    @Test("a desktop pressed during the swap is where you end up")
    func pressDuringSwap() async {
        let board = Board(on: 1)
        board.tile([1], on: 1)
        board.tile([3], on: 3)
        let switcher = SpaceSwitcher(desktop: board.desktop(), patience: 5)
        board.duringSwap = { await switcher.go(to: 2) }
        await switcher.swap(with: 3)
        #expect(board.tiled(on: 3) == [1])
        #expect(board.tiled(on: 1) == [3])
        #expect(board.space == 2)
        #expect(!board.events.contains(.focused(1)))
    }
}
