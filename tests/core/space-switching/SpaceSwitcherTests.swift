import Foundation
import Testing

@testable import Macarchy

struct SpaceSwitcherTests {
    enum Event: Equatable {
        case swipe(SpaceSwitcher.Direction, Int)
        case yabai(Int)
        case moved(window: Int, space: Int)
        /// The bar told a window's app is on another Space now.
        case drawn(app: String, from: Int, to: Int)
        case focused(Int)
    }

    enum Press {
        case go(Int)
        case move(Int)
        /// A trackpad swipe.
        case step(SpaceSwitcher.Direction)
    }

    /// One display of five Spaces, where Space n has id n * 10. A switch
    /// lands three looks after it is sent, and presses are made at given
    /// looks, as keys pressed while a switch is landing.
    final class Desk: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Int
        private var landing: [Int] = []
        private var sinceSent = 0
        private var looks = 0
        private var presses: [Int: Press]
        private var log: [Event] = []

        var pointerDisplay = [10, 20, 30, 40, 50]
        var hasLayout = true
        var allowed = true
        var overlay = false
        var swipesWork = true
        /// Switches are sent but never land, as when Mission Control eats them.
        var stuck = false
        /// The Dock's own order of Space ids, when it differs from the
        /// window server's, as after yabai's scripting addition swaps Spaces.
        /// Swipes go along this order, showing only the last Space, as the
        /// real Dock does, or each one passed with `dockShowsEachStep`.
        var dockOrder: [Int]?
        var dockShowsEachStep = false
        var dockID = 1
        /// A Space showing on another display.
        var otherDisplay: Int?
        var focusedWindow: Int? = 7
        /// A press made while yabai moves the window.
        var pressDuringMove: Press?
        var switcher: SpaceSwitcher?

        init(on index: Int, presses: [Int: Press] = [:]) {
            current = index
            self.presses = presses
        }

        var space: Int { lock.withLock { current } }
        var events: [Event] { lock.withLock { log } }

        func showing() -> Set<Int> {
            lock.withLock { Set([current * 10] + (otherDisplay.map { [$0] } ?? [])) }
        }

        func record(_ event: Event) { lock.withLock { log.append(event) } }

        func head(to index: Int) {
            lock.withLock {
                guard !stuck, (1...5).contains(index) else { return }
                landing.append(index)
                sinceSent = 0
            }
        }

        func swipe(_ direction: SpaceSwitcher.Direction, _ steps: Int) -> Bool {
            record(.swipe(direction, steps))
            guard swipesWork else { return false }
            guard let order = dockOrder, let from = order.firstIndex(of: space * 10) else {
                head(to: space + (direction == .right ? steps : -steps))
                return true
            }
            // Along the Dock's order, stopping at its ends.
            let step = direction == .right ? 1 : -1
            let passed = stride(from: from + step, through: from + step * steps, by: step)
                .filter(order.indices.contains)
            for position in dockShowsEachStep ? passed : passed.suffix(1) {
                head(to: order[position] / 10)
            }
            return true
        }

        /// One look later; returns a press due now.
        func tick() -> Press? {
            lock.withLock {
                looks += 1
                sinceSent += 1
                if !landing.isEmpty, sinceSent >= 3 {
                    current = landing.removeFirst()
                    sinceSent = 0
                }
                return presses.removeValue(forKey: looks)
            }
        }

        func press(_ press: Press) async {
            switch press {
            case .go(let index): await switcher?.go(to: index)
            case .move(let index): await switcher?.move(to: index)
            case .step(let direction): await switcher?.step(direction)
            }
        }

        func desktop() -> SpaceSwitcher.Desktop {
            SpaceSwitcher.Desktop(
                layout: {
                    guard self.hasLayout else { return nil }
                    return SpaceSwitcher.Layout(
                        ids: Dictionary(uniqueKeysWithValues: (1...5).map { ($0, $0 * 10) }),
                        pointerDisplay: self.pointerDisplay)
                },
                showing: { self.showing() },
                gesturesAllowed: { self.allowed },
                overlayOpen: { self.overlay },
                swipe: { self.swipe($0, $1) },
                yabaiFocus: { index in
                    self.record(.yabai(index))
                    self.head(to: index)
                },
                focusedWindow: {
                    self.focusedWindow.map {
                        SpaceSwitcher.Window(id: $0, app: "Notes", space: self.space)
                    }
                },
                moveWindow: { window, space in
                    self.record(.moved(window: window, space: space))
                    if let press = self.pressDuringMove {
                        self.pressDuringMove = nil
                        await self.press(press)
                    }
                    return true
                },
                windowMoved: { window, space in
                    self.record(.drawn(app: window.app, from: window.space, to: space))
                },
                focusWindow: { self.record(.focused($0)) },
                pause: {
                    if let press = self.tick() { await self.press(press) }
                },
                dock: { self.dockID })
        }
    }

    func run(_ desk: Desk, _ press: Press) async {
        let switcher = desk.switcher ?? SpaceSwitcher(desktop: desk.desktop(), patience: 30)
        desk.switcher = switcher
        await desk.press(press)
    }

    @Test("a single press swipes once, straight to the Space")
    func singlePress() async {
        let desk = Desk(on: 1)
        await run(desk, .go(3))
        #expect(desk.events == [.swipe(.right, 2)])
        #expect(desk.space == 3)
    }

    /// From 2: 4, then 2, 4 and 2 while the first is landing.
    @Test("presses made while a switch lands are skipped, and the last is sent once it lands")
    func coalescesBurst() async {
        let desk = Desk(on: 2, presses: [1: .go(2), 2: .go(4), 3: .go(2)])
        await run(desk, .go(4))
        #expect(desk.events == [.swipe(.right, 2), .swipe(.left, 2)])
        #expect(desk.space == 2)
    }

    @Test("moving a window follows it and focuses it on arrival")
    func moveFollows() async {
        let desk = Desk(on: 1)
        await run(desk, .move(3))
        #expect(
            desk.events == [
                .moved(window: 7, space: 3), .drawn(app: "Notes", from: 1, to: 3),
                .swipe(.right, 2), .focused(7)
            ])
        #expect(desk.space == 3)
    }

    /// ⌘⇧3 then ⌘2 at once, where the ⌘2 used to be dropped.
    @Test("a switch pressed right after a move waits its turn instead of being dropped")
    func switchBackAfterMove() async {
        let desk = Desk(on: 1, presses: [1: .go(2)])
        await run(desk, .move(3))
        #expect(
            desk.events == [
                .moved(window: 7, space: 3), .drawn(app: "Notes", from: 1, to: 3),
                .swipe(.right, 2), .swipe(.left, 1)
            ])
        #expect(desk.space == 2)
    }

    @Test("a press made while yabai moves the window decides where the switch goes")
    func pressDuringMoveWins() async {
        let desk = Desk(on: 1)
        desk.pressDuringMove = .go(2)
        await run(desk, .move(3))
        // The press ran while yabai moved the window, so its switch comes first.
        #expect(
            desk.events == [
                .moved(window: 7, space: 3), .swipe(.right, 1),
                .drawn(app: "Notes", from: 1, to: 3)
            ])
        #expect(desk.space == 2)
    }

    @Test("with no focused window, moving still changes Space")
    func moveWithoutWindow() async {
        let desk = Desk(on: 1)
        desk.focusedWindow = nil
        await run(desk, .move(3))
        #expect(desk.events == [.swipe(.right, 2)])
        #expect(desk.space == 3)
    }

    @Test("moving a window to the Space showing focuses it without switching")
    func moveToCurrentSpace() async {
        let desk = Desk(on: 3)
        await run(desk, .move(3))
        #expect(desk.events == [.moved(window: 7, space: 3), .focused(7)])
    }

    @Test("a Space on another display goes through yabai")
    func otherDisplay() async {
        let desk = Desk(on: 1)
        desk.pointerDisplay = [10, 20, 30]
        await run(desk, .go(5))
        #expect(desk.events == [.yabai(5)])
        #expect(desk.space == 5)
    }

    @Test("with Mission Control or App Exposé open, yabai switches")
    func overlayOpen() async {
        let desk = Desk(on: 1)
        desk.overlay = true
        await run(desk, .go(3))
        #expect(desk.events == [.yabai(3)])
    }

    @Test("without permission to post events, yabai switches")
    func noPermission() async {
        let desk = Desk(on: 1)
        desk.allowed = false
        await run(desk, .go(3))
        #expect(desk.events == [.yabai(3)])
    }

    @Test("a swipe that could not be made falls back to yabai, which goes by index")
    func swipeFails() async {
        let desk = Desk(on: 1)
        desk.swipesWork = false
        await run(desk, .go(3))
        #expect(desk.events == [.swipe(.right, 2), .yabai(3)])
        #expect(desk.space == 3)
    }

    @Test("without the window server's Spaces, yabai switches")
    func noLayout() async {
        let desk = Desk(on: 1)
        desk.hasLayout = false
        await run(desk, .go(3))
        #expect(desk.events == [.yabai(3)])
    }

    @Test("a Space that does not exist is left alone")
    func missingSpace() async {
        let desk = Desk(on: 1)
        await run(desk, .go(9))
        #expect(desk.events.isEmpty)
        #expect(desk.space == 1)
    }

    @Test("the Space already showing sends nothing")
    func alreadyShowing() async {
        let desk = Desk(on: 3)
        await run(desk, .go(3))
        #expect(desk.events.isEmpty)
    }
}

extension SpaceSwitcherTests {
    @Test("a switch that never lands is tried once through yabai, then given up on")
    func neverLands() async {
        let desk = Desk(on: 1)
        desk.stuck = true
        await run(desk, .move(3))
        // No window is focused, as the Space never showed.
        #expect(
            desk.events == [
                .moved(window: 7, space: 3), .drawn(app: "Notes", from: 1, to: 3),
                .swipe(.right, 2),
                .yabai(3)
            ])
        #expect(desk.space == 1)
    }
}
