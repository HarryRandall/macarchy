import Testing

@testable import Macarchy

/// Trackpad swipes through `SpaceSwitcher.step`, on the same fake desk.
extension SpaceSwitcherTests {
    @Test("a trackpad swipe goes one Space along from the one showing")
    func swipeSteps() async {
        let desk = Desk(on: 2)
        await run(desk, .step(.left))
        #expect(desk.events == [.swipe(.left, 1)])
        #expect(desk.space == 1)
    }

    @Test("a swipe past either end does nothing")
    func swipeAtEnds() async {
        let first = Desk(on: 1)
        await run(first, .step(.left))
        let last = Desk(on: 5)
        await run(last, .step(.right))
        #expect(first.events.isEmpty && last.events.isEmpty)
    }

    @Test("a second swipe while the first lands goes on from where the first is heading")
    func quickSwipes() async {
        let desk = Desk(on: 1, presses: [1: .step(.right)])
        await run(desk, .step(.right))
        #expect(desk.events == [.swipe(.right, 1), .swipe(.right, 1)])
        #expect(desk.space == 3)
    }

    @Test("a swipe after a shortcut press goes on from the Space pressed")
    func swipeAfterPress() async {
        let desk = Desk(on: 1, presses: [1: .go(4), 2: .step(.left)])
        await run(desk, .go(2))
        #expect(desk.events == [.swipe(.right, 1), .swipe(.right, 1)])
        #expect(desk.space == 3)
    }
}
