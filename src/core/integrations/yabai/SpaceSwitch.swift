import Foundation

/// Switches Spaces one at a time, always on to the latest Space asked for.
///
/// yabai cannot tell on macOS 27 when a switch is still sliding, so every
/// `space --focus` waits behind the slides before it, about half a second
/// each, and one for the Space a slide is leaving is refused as already
/// current: pressing 4 and then 2 quickly from 2 stays on 4. So each press
/// only records its Space. The press that holds the lock sends one switch,
/// waits for it to land, then goes on to whichever Space was asked for last,
/// skipping the ones pressed in between.
///
/// Each switch's work finishes before the next starts, and the lock is held
/// until it has: InstantSpaceSwitcher's tool stays running for 0.3 s while
/// its swipe settles, and a second one running then takes the first's
/// swipes for its own, which overshoots and can leave the Dock black.
public struct SpaceSwitch: Sendable {
    /// Space ids by index, as yabai numbers them.
    var spaces: @Sendable () async -> [Int: Int]
    /// The ids of the Spaces showing now, which change once a slide ends.
    var showing: @Sendable () -> Set<Int>
    /// Starts a switch, returning the work still running for it.
    var focus: @Sendable (Int) -> Task<Void, Never>
    /// A short wait between looks at whether a switch has landed.
    var pause: @Sendable () async -> Void
    let directory: URL
    /// Pauses before a switch that has not landed is given up on, as for a
    /// Space that does not exist or while Mission Control is open.
    var patience = 150

    public static var live: SpaceSwitch {
        let integrations = Integrations()
        return SpaceSwitch(
            spaces: {
                if let ids = SpacesReading.indicesFromWindowServer() { return ids }
                return await indices(integrations)
            },
            showing: { SpacesReading.currentSpaceIDs() ?? [] },
            focus: { index in
                Task {
                    guard await !InstantSpaceSwitcher.focus(index, integrations: integrations)
                    else { return }
                    _ = await integrations.execute(
                        Paths.yabai, ["-m", "space", "--focus", String(index)])
                }
            },
            pause: { try? await Task.sleep(for: .milliseconds(10)) },
            directory: Paths.stateDirectory)
    }

    /// The Space last pressed, which the refocus signals also read.
    static func targetURL(in directory: URL) -> URL { directory.appending(path: "space-target") }
    private var targetURL: URL { Self.targetURL(in: directory) }
    private var lockURL: URL { directory.appending(path: "space-switch.lock") }

    public func go(to index: Int) async {
        record(index)
        guard var held = take() else { return }
        var wanted = index
        // A Space that does not exist is left alone, as yabai does;
        // InstantSpaceSwitcher would go to the last one instead.
        let ids = await spaces()
        while true {
            while let id = ids[wanted] {
                let switching = focus(wanted)
                let arrived = await landed(on: id)
                await switching.value
                guard arrived, let next = newer(than: wanted, ids) else { break }
                wanted = next
            }
            // A press can record its Space just as the lock is let go, and
            // then finds it still held; look once more after letting go.
            release(held)
            guard let next = newer(than: wanted, ids), let again = take() else { return }
            held = again
            wanted = next
        }
    }

    /// The Space pressed since `wanted`, when there is one not showing yet.
    private func newer(than wanted: Int, _ ids: [Int: Int]) -> Int? {
        guard let next = recorded(), next != wanted, let id = ids[next], !showing().contains(id)
        else { return nil }
        return next
    }

    private func landed(on id: Int) async -> Bool {
        for _ in 0..<patience {
            if showing().contains(id) { return true }
            await pause()
        }
        return showing().contains(id)
    }

    private func record(_ index: Int) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("\(index)\n".utf8).write(to: targetURL, options: .atomic)
    }

    private func recorded() -> Int? {
        (try? String(contentsOf: targetURL, encoding: .utf8))
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// The switching lock, or nil while another press holds it.
    private func take() -> Int32? {
        let descriptor = open(lockURL.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return descriptor
    }

    private func release(_ descriptor: Int32) {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }

    private struct Space: Decodable {
        let id: Int
        let index: Int
    }

    private static func indices(_ integrations: Integrations) async -> [Int: Int] {
        let result = await integrations.execute(Paths.yabai, ["-m", "query", "--spaces"])
        guard result.ok,
            let spaces = try? JSONDecoder().decode([Space].self, from: Data(result.stdout.utf8))
        else { return [:] }
        return Dictionary(spaces.map { ($0.index, $0.id) }, uniquingKeysWith: { first, _ in first })
    }
}
