import Foundation
import Macarchy

/// Polling also follows symlinks and skhd's dotfile fallback after an atomic replacement.
@MainActor
final class ShortcutsBroadcast {
    private var task: Task<Void, Never>?
    private var lastRevision: String?
    private var lastError: String?

    func written(_ state: ShortcutsState) { lastRevision = state.revision }

    func start(send: @escaping @MainActor (BridgeEvent) -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                self?.poll(send: send)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func poll(send: @MainActor (BridgeEvent) -> Void) {
        do {
            let state = ShortcutsState(try SkhdShortcuts().read())
            if state.revision != lastRevision || lastError != nil {
                lastRevision = state.revision
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
