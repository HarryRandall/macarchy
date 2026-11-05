import Foundation

/// Switches Spaces from `macarchy space` while the app is not switching
/// (`SpaceSwitchRequest`), one at a time across processes, always on to the
/// latest Space asked for.
///
/// Each press is its own process. So each only records its Space, and the
/// one that holds the lock switches with a `SpaceSwitcher` of its own,
/// waits for the switch to land, then goes on to whichever Space was asked
/// for last, skipping the ones pressed in between. A switch sent while
/// another is still landing works it out from a Space the window server
/// reports mid-swipe and overshoots, so each finishes before the next.
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
    /// The focused window, moving it and focusing it again, for `move(to:)`.
    var focusedWindow: @Sendable () async -> Int? = { nil }
    var moveWindow: @Sendable (_ window: Int, _ space: Int) async -> Bool = { _, _ in false }
    var focusWindow: @Sendable (Int) async -> Void = { _ in }

    public static var live: SpaceSwitch {
        let integrations = Integrations()
        let desktop = SpaceSwitcher.Desktop.live(integrations: integrations)
        return SpaceSwitch(
            spaces: {
                if let ids = SpacesReading.indicesFromWindowServer() { return ids }
                return await indices(integrations)
            },
            showing: desktop.showing,
            focus: { index in
                Task { await SpaceSwitcher(desktop: desktop).go(to: index) }
            },
            pause: desktop.pause,
            directory: Paths.stateDirectory,
            focusedWindow: desktop.focusedWindow,
            moveWindow: desktop.moveWindow,
            focusWindow: desktop.focusWindow)
    }

    /// The Space last pressed, which the refocus signals also read.
    static func targetURL(in directory: URL) -> URL { directory.appending(path: "space-target") }
    private var targetURL: URL { Self.targetURL(in: directory) }
    private var lockURL: URL { directory.appending(path: "space-switch.lock") }

    public func go(to index: Int) async {
        record(index)
        guard var held = take() else { return }
        var wanted = index
        // A Space that does not exist is left alone, as yabai does.
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

    /// Moves the focused window to Space `index` and follows it there. The
    /// window moves at once, whoever is switching; it is focused again only
    /// when this process switched and nothing was pressed since.
    public func move(to index: Int) async {
        var window: Int?
        if let focused = await focusedWindow(), await moveWindow(focused, index) {
            window = focused
        }
        await go(to: index)
        guard let window, recorded() == index, let id = await spaces()[index],
            showing().contains(id)
        else { return }
        await focusWindow(window)
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
        Self.record(index, in: directory)
    }

    /// Records the Space last pressed, whoever switches to it, so the refocus
    /// signal can tell a switch is still on its way.
    public static func record(_ index: Int, in directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("\(index)\n".utf8).write(to: targetURL(in: directory), options: .atomic)
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
