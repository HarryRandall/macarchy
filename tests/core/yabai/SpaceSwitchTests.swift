import Foundation
import Testing

@testable import Macarchy

struct SpaceSwitchTests {
    /// A desktop whose switches land in order, a few looks after each is
    /// sent, as yabai's queued slides do. Space n has id n * 10. Presses are
    /// made at given looks, as keys pressed while a slide is under way.
    private final class Desk: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Int
        private var queue: [Int] = []
        private var sinceSent = 0
        private var looksSoFar = 0
        private var presses: [Int: Int]
        private(set) var sent: [Int] = []
        private(set) var windows: [String] = []

        init(on index: Int, presses: [Int: Int] = [:]) {
            current = index * 10
            self.presses = presses
        }

        func showing() -> Set<Int> { lock.withLock { [current] } }
        func record(_ change: String) { lock.withLock { windows.append(change) } }
        var space: Int { lock.withLock { current / 10 } }

        func focus(_ index: Int) {
            lock.withLock {
                sent.append(index)
                if index * 10 != current { queue.append(index * 10) }
            }
        }

        /// One look later; returns a press due now.
        func tick() -> Int? {
            lock.withLock {
                looksSoFar += 1
                sinceSent += 1
                if !queue.isEmpty, sinceSent >= 3 {
                    current = queue.removeFirst()
                    sinceSent = 0
                }
                return presses.removeValue(forKey: looksSoFar)
            }
        }
    }

    /// Counts the switches whose work is still running, as InstantSpaceSwitcher's
    /// tool keeps running for a moment after its switch lands.
    private actor Running {
        private var now = 0
        private(set) var most = 0
        func start() {
            now += 1
            most = max(most, now)
        }
        func finish() { now -= 1 }
    }

    private static func switcher(
        _ desk: Desk, in directory: URL, running: Running? = nil
    ) -> SpaceSwitch {
        SpaceSwitch(
            spaces: { Dictionary(uniqueKeysWithValues: (1...5).map { ($0, $0 * 10) }) },
            showing: { desk.showing() },
            // Sent before returning, as the real tools are started at once;
            // only their settling afterwards is left running.
            focus: { index in
                desk.focus(index)
                return Task {
                    await running?.start()
                    for _ in 0..<20 { await Task.yield() }
                    await running?.finish()
                }
            },
            pause: {
                if let press = desk.tick() {
                    await switcher(desk, in: directory, running: running).go(to: press)
                }
            },
            directory: directory, patience: 20,
            focusedWindow: { 7 },
            moveWindow: { window, space in
                desk.record("move \(window) to \(space)")
                return true
            },
            focusWindow: { desk.record("focus \($0)") })
    }

    private func run(
        _ desk: Desk, going to: Int, moving: Bool = false, running: Running? = nil
    ) async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-space-switch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let switcher = Self.switcher(desk, in: directory, running: running)
        if moving {
            await switcher.move(to: to)
        } else {
            await switcher.go(to: to)
        }
    }

    /// A second InstantSpaceSwitcher running while the first settles takes
    /// the first's swipes for its own and overshoots.
    @Test("each switch's work finishes before the next switch starts")
    func oneSwitcherAtATime() async throws {
        let desk = Desk(on: 2, presses: [1: 2])
        let running = Running()
        try await run(desk, going: 4, running: running)
        #expect(desk.sent == [4, 2])
        #expect(desk.space == 2)
        #expect(await running.most == 1)
    }

    /// From 2, 4 then 2 then 4 then 2: yabai would queue every slide and
    /// refuse the 2s pressed while still on 2.
    @Test("presses made during a slide are skipped, and the last one is sent once it lands")
    func coalescesBurst() async throws {
        let desk = Desk(on: 2, presses: [1: 2, 2: 4, 3: 2])
        try await run(desk, going: 4)
        #expect(desk.sent == [4, 2])
        #expect(desk.space == 2)
    }

    @Test("a single press switches once")
    func singlePress() async throws {
        let desk = Desk(on: 1)
        try await run(desk, going: 3)
        #expect(desk.sent == [3])
        #expect(desk.space == 3)
    }

    @Test("a Space that does not exist is given up on without waiting for it")
    func missingSpace() async throws {
        let desk = Desk(on: 1)
        try await run(desk, going: 9)
        #expect(desk.sent.isEmpty)
        #expect(desk.space == 1)
    }

    @Test("moving a window here moves it, switches and focuses it once it lands")
    func moveFollows() async throws {
        let desk = Desk(on: 1)
        try await run(desk, going: 3, moving: true)
        #expect(desk.windows == ["move 7 to 3", "focus 7"])
        #expect(desk.sent == [3])
        #expect(desk.space == 3)
    }

    @Test("a press made during the move's switch leaves the window unfocused")
    func moveThenPress() async throws {
        let desk = Desk(on: 1, presses: [1: 2])
        try await run(desk, going: 3, moving: true)
        #expect(desk.windows == ["move 7 to 3"])
        #expect(desk.sent == [3, 2])
        #expect(desk.space == 2)
    }
}
