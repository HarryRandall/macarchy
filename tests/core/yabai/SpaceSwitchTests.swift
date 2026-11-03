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

        init(on index: Int, presses: [Int: Int] = [:]) {
            current = index * 10
            self.presses = presses
        }

        func showing() -> Set<Int> { lock.withLock { [current] } }
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

    /// Holds every switch's work open, as InstantSpaceSwitcher's tool stays
    /// running after its switch lands, until a second switch has been sent.
    private actor Settling {
        private var open = false
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private(set) var sentWhileHeld: [Int] = []

        func hold() async {
            guard !open else { return }
            await withCheckedContinuation { waiting.append($0) }
        }

        func note(_ sent: [Int]) {
            guard !open else { return }
            sentWhileHeld = sent
            if sent.count >= 2 { release() }
        }

        func release() {
            open = true
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    private static func switcher(
        _ desk: Desk, in directory: URL, settling: Settling? = nil
    ) -> SpaceSwitch {
        SpaceSwitch(
            spaces: { Dictionary(uniqueKeysWithValues: (1...5).map { ($0, $0 * 10) }) },
            showing: { desk.showing() },
            // Sent before returning, as the real tools are started at once;
            // only their settling afterwards is left running.
            focus: { index in
                desk.focus(index)
                return Task { await settling?.hold() }
            },
            pause: {
                await settling?.note(desk.sent)
                if let press = desk.tick() {
                    await switcher(desk, in: directory, settling: settling).go(to: press)
                }
            },
            directory: directory, patience: 20)
    }

    private func run(_ desk: Desk, going to: Int, settling: Settling? = nil) async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-space-switch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        await Self.switcher(desk, in: directory, settling: settling).go(to: to)
        await settling?.release()
    }

    @Test("the next switch is sent once the last one shows, while its tool is still settling")
    func doesNotWaitForSettling() async throws {
        let desk = Desk(on: 2, presses: [1: 2])
        let settling = Settling()
        try await run(desk, going: 4, settling: settling)
        #expect(await settling.sentWhileHeld == [4, 2])
        #expect(desk.space == 2)
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
}
