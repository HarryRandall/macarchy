import Foundation
import Macarchy

/// Polling also follows symlinks and skhd's dotfile fallback after an atomic replacement.
///
/// Nothing is read while no page is showing, since the page reads afresh each
/// time it comes forward. The desktop count is asked of yabai less often than
/// skhdrc is read, since it costs a process each time.
@MainActor
final class ShortcutsBroadcast {
    private var task: Task<Void, Never>?
    private var lastRevision: String?
    private var lastDesktops: Int?
    private var lastError: String?
    private var ticks = 0
    private static let desktopEvery = 5

    func written(_ state: ShortcutsState) {
        lastRevision = state.revision
        lastDesktops = state.desktops
    }

    func start(
        integrations: Integrations = Integrations(),
        watched: @escaping @MainActor () -> Bool = { true },
        send: @escaping @MainActor (BridgeEvent) -> Void
    ) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.poll(integrations: integrations, watched: watched, send: send)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func poll(
        integrations: Integrations, watched: @MainActor () -> Bool,
        send: @MainActor (BridgeEvent) -> Void
    ) async {
        guard watched() else { return }
        do {
            let snapshot = try SkhdShortcuts().read()
            defer { ticks += 1 }
            var desktops = lastDesktops
            if snapshot.revision != lastRevision || ticks % Self.desktopEvery == 0 {
                desktops = await integrations.desktopCount()
            }
            let state = ShortcutsState(snapshot, desktops: desktops)
            if state.revision != lastRevision || desktops != lastDesktops || lastError != nil {
                lastRevision = state.revision
                lastDesktops = desktops
                lastError = nil
                send(.shortcutsChanged(state))
            }
        } catch {
            let message = "Your shortcuts could not be read: \(error.localizedDescription)"
            if message != lastError {
                lastError = message
                send(.shortcutsUnavailable(message))
            }
        }
    }

    deinit { task?.cancel() }
}
