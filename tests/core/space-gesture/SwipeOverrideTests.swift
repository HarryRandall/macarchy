import SpaceGesture
import Testing

/// How the trackpad interception treats each event of a swipe. Nothing
/// here creates a tap or posts an event.
struct SwipeOverrideTests {
    private static let dock: Int64 = 30
    private static let companion: Int64 = 29

    /// A sideways Dock swipe from the trackpad.
    private static func swipe(
        _ phase: Int64, progress: Double = 0, velocity: Double = 0, motion: Int64 = 1,
        hid: Int64 = 23, pid: Int64 = 0
    ) -> SGSwipeEvent {
        SGSwipeEvent(
            eventType: dock, hidType: hid, motion: motion, phase: phase, progress: progress,
            velocity: velocity, sourcePid: pid)
    }

    private static let companionEvent = SGSwipeEvent(
        eventType: companion, hidType: 0, motion: 0, phase: 0, progress: 0, velocity: 0,
        sourcePid: 0)

    /// Runs events through one swipe's state, as the tap does.
    private struct Swipe {
        var state = SGSwipeState(tracking: false, fired: false)
        var modern = true
        var overlay = false

        mutating func send(_ event: SGSwipeEvent) -> (SGSwipeAction, Int32) {
            var direction: Int32 = 0
            let open: @convention(c) () -> Bool = overlay ? { true } : { false }
            let action = sg_swipe_decide(&state, event, modern, open, &direction)
            return (action, direction)
        }
    }

    @Test("a swipe switches once, on its first move, and the Dock sees none of it but the end")
    func switchesOnce() {
        var swipe = Swipe()
        #expect(swipe.send(Self.swipe(1)) == (SGSwipeSwallow, -1))
        #expect(swipe.send(Self.companionEvent) == (SGSwipeSwallow, -1))
        #expect(
            swipe.send(Self.swipe(2, progress: 0.2)) == (
                SGSwipeSwallow, Int32(SGDirectionRight.rawValue)
            ))
        #expect(swipe.send(Self.swipe(2, progress: 0.6)) == (SGSwipeSwallow, -1))
        // macOS 27 needs the real end to close the gesture, with its motion zeroed.
        #expect(swipe.send(Self.swipe(4, velocity: 900)) == (SGSwipePassStill, -1))
        #expect(!swipe.state.tracking)
        #expect(swipe.send(Self.companionEvent) == (SGSwipePass, -1))
    }

    @Test("on macOS 26 the end is held back too")
    func legacyEnd() {
        var swipe = Swipe()
        swipe.modern = false
        _ = swipe.send(Self.swipe(1))
        _ = swipe.send(Self.swipe(2, progress: -0.3))
        #expect(swipe.send(Self.swipe(4)) == (SGSwipeSwallow, -1))
    }

    @Test("a flick too short for progress switches by its velocity")
    func flick() {
        var swipe = Swipe()
        _ = swipe.send(Self.swipe(1))
        #expect(
            swipe.send(Self.swipe(4, velocity: -500)) == (
                SGSwipePassStill, Int32(SGDirectionLeft.rawValue)
            ))
    }

    @Test("a swipe begun in Mission Control or App Exposé goes to the Dock untouched")
    func overlay() {
        var swipe = Swipe()
        swipe.overlay = true
        #expect(swipe.send(Self.swipe(1)) == (SGSwipePass, -1))
        #expect(swipe.send(Self.swipe(2, progress: 0.4)) == (SGSwipePass, -1))
        #expect(swipe.send(Self.companionEvent) == (SGSwipePass, -1))
        #expect(swipe.send(Self.swipe(4, velocity: 300)) == (SGSwipePass, -1))
    }

    @Test("vertical swipes, other gestures and other processes' swipes pass")
    func passesOthers() {
        var swipe = Swipe()
        #expect(swipe.send(Self.swipe(1, motion: 2)) == (SGSwipePass, -1))
        #expect(swipe.send(Self.swipe(1, hid: 7)) == (SGSwipePass, -1))
        #expect(swipe.send(Self.swipe(1, pid: 4242)) == (SGSwipePass, -1))
        let scroll = SGSwipeEvent(
            eventType: 22, hidType: 0, motion: 0, phase: 1, progress: 0, velocity: 0, sourcePid: 0)
        #expect(swipe.send(scroll) == (SGSwipePass, -1))
        #expect(!swipe.state.tracking)
    }

    @Test("a cancelled swipe ends tracking; one never tracked passes")
    func cancelled() {
        var swipe = Swipe()
        #expect(swipe.send(Self.swipe(8)) == (SGSwipePass, -1))
        _ = swipe.send(Self.swipe(1))
        #expect(swipe.send(Self.swipe(8)) == (SGSwipeSwallow, -1))
        #expect(!swipe.state.tracking)
    }
}
