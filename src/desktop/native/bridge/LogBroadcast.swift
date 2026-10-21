import Foundation
import Observation

/// Tells the page the activity log changed, once per burst: a restart of
/// every service writes an entry each, and the page reads the whole log again
/// on every event.
@MainActor
final class LogBroadcast {
    private let delay: Duration
    private var log: CommandLog?
    private var send: (@MainActor () -> Void)?
    private var pending: Task<Void, Never>?

    init(delay: Duration = .milliseconds(150)) {
        self.delay = delay
    }

    func start(_ log: CommandLog, send: @escaping @MainActor () -> Void) {
        self.log = log
        self.send = send
        observe()
    }

    private func observe() {
        guard let log else { return }
        withObservationTracking {
            _ = log.entries
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observe()
                self?.schedule()
            }
        }
    }

    /// Entries added while an event is waiting go out with it.
    private func schedule() {
        guard pending == nil else { return }
        let delay = delay
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.pending = nil
            self?.send?()
        }
    }

    deinit { pending?.cancel() }
}
