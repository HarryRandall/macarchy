import Testing

@testable import Macarchy

/// The Dock swiping through Spaces in an order other than the window
/// server's. yabai's scripting addition can reorder Spaces without the Dock
/// knowing, and swipes then land on the wrong desktop.
extension SpaceSwitcherTests {
    /// Recorded on 6 November 2026: the window server, yabai and Mission
    /// Control had ids 8, 7, 5, 6, 4 while swipes went 8, 7, 4, 5, 6. As the
    /// desk's ids, Space 5 sits between 2 and 3 for the Dock.
    static let swappedDock = [10, 20, 50, 30, 40]

    func swappedDesk(on index: Int) -> Desk {
        let desk = Desk(on: index)
        desk.dockOrder = Self.swappedDock
        return desk
    }

    @Test("a swipe the Dock takes to another Space is put right through yabai")
    func misplacedSwipe() async {
        // One swipe right from 2 showed 5.
        let desk = swappedDesk(on: 2)
        await run(desk, .go(3))
        #expect(desk.events == [.swipe(.right, 1), .yabai(3)])
        #expect(desk.space == 3)
    }

    @Test("swipes that stop short of the Space are finished by yabai")
    func shortSwipe() async {
        // Three swipes right from 2 went past 5 and 3 to 4.
        let desk = swappedDesk(on: 2)
        await run(desk, .go(5))
        #expect(desk.events == [.swipe(.right, 3), .yabai(5)])
        #expect(desk.space == 5)
    }

    @Test("once the Dock's order is found wrong, later switches go straight through yabai")
    func distrustsDock() async {
        let desk = swappedDesk(on: 2)
        await run(desk, .go(3))
        await run(desk, .go(1))
        #expect(desk.events == [.swipe(.right, 1), .yabai(3), .yabai(1)])
        #expect(desk.space == 1)
    }

    @Test("after the Dock restarts, swipes are tried again")
    func trustsRestartedDock() async {
        let desk = swappedDesk(on: 2)
        await run(desk, .go(3))
        desk.dockID = 2
        desk.dockOrder = nil
        await run(desk, .go(1))
        #expect(desk.events == [.swipe(.right, 1), .yabai(3), .swipe(.left, 2)])
        #expect(desk.space == 1)
    }

    @Test("a moved window is focused once yabai has put the switch right")
    func moveAfterMisplacedSwipe() async {
        let desk = swappedDesk(on: 2)
        await run(desk, .move(3))
        #expect(
            desk.events == [
                .moved(window: 7, space: 3), .drawn(app: "Notes", from: 2, to: 3),
                .swipe(.right, 1), .yabai(3), .focused(7)
            ])
        #expect(desk.space == 3)
    }

    /// Every press logged on the desktop that showed the fault.
    @Test(
        "every hop recorded with the Dock out of order ends on the Space pressed",
        arguments: [(1, 2), (2, 3), (5, 4), (2, 5), (4, 3), (3, 2), (5, 1), (4, 1), (1, 5)])
    func recordedHops(from: Int, to: Int) async {
        let desk = swappedDesk(on: from)
        await run(desk, .go(to))
        #expect(desk.space == to)
    }

    @Test("a swipe passing the Spaces on its way is not taken for a wrong one")
    func passesOnTheWay() async {
        let desk = Desk(on: 1)
        desk.dockOrder = [10, 20, 30, 40, 50]
        desk.dockShowsEachStep = true
        await run(desk, .go(5))
        #expect(desk.events == [.swipe(.right, 4)])
        #expect(desk.space == 5)
    }

    @Test("the Space showing on another display is not taken for a wrong one")
    func otherDisplayShowing() async {
        let desk = Desk(on: 1)
        desk.dockOrder = [10, 20, 30, 40, 50]
        desk.otherDisplay = 90
        await run(desk, .go(3))
        #expect(desk.events == [.swipe(.right, 2)])
        #expect(desk.space == 3)
    }
}
