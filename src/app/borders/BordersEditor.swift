import Macarchy
import Foundation
import Observation

@MainActor
@Observable
final class BordersEditor {
    var draft = BorderAppearance()
    private(set) var applied = BorderAppearance()
    private(set) var live = true
    private(set) var isApplying = false
    private(set) var loaded = false
    var error: String?
    private var pending: Task<Void, Never>?
    private let commit: (BorderAppearance) async throws -> Void

    var hasChanges: Bool { draft != applied }

    init(commit: @escaping (BorderAppearance) async throws -> Void) {
        self.commit = commit
    }

    func load(_ appearance: BorderAppearance) {
        guard !isApplying else { return }
        pending?.cancel()
        draft = appearance
        applied = appearance
        loaded = true
        error = nil
    }

    func changed() {
        guard !isApplying else { return }
        pending?.cancel()
        guard live, hasChanges else { return }
        pending = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await apply()
        }
    }

    /// Enabling live mode never silently commits an existing manual draft.
    func setLive(_ enabled: Bool) {
        guard !enabled || (!isApplying && !hasChanges) else { return }
        // Let an already-started write finish, but stop queued live edits.
        if !isApplying { pending?.cancel() }
        live = enabled
    }

    func discard() {
        guard !isApplying else { return }
        pending?.cancel()
        draft = applied
        error = nil
    }

    func apply() async {
        guard hasChanges, !isApplying else { return }
        let submitted = draft
        isApplying = true
        error = nil
        do {
            try await commit(submitted)
            applied = submitted
        } catch {
            self.error =
                "Some changes may already have applied. \(error.localizedDescription) Retry Apply to finish."
            live = false
        }
        isApplying = false
        if live, hasChanges { changed() }
    }
}
