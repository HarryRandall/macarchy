import Foundation

/// Named maintenance operations. Snapshot identifiers are resolved from the store,
/// never treated as paths supplied by the interface.
public struct AdvancedConfiguration: Sendable {
    public enum File: String, Codable, Sendable { case bordersrc, yabairc, sketchybarrc }
    public let integrations: Integrations

    public init(integrations: Integrations = Integrations()) { self.integrations = integrations }

    public func rebuild(_ file: File) throws -> GeneratedFile.Outcome {
        let configuration = StartupConfiguration()
        let outcome: GeneratedFile.Outcome
        switch file {
        case .bordersrc: outcome = configuration.generateBordersRC()
        case .yabairc: outcome = configuration.generateYabaiRC()
        case .sketchybarrc: outcome = configuration.generateSketchybarRC()
        }
        if case .failed(let message) = outcome { throw ConfigurationError(message) }
        return outcome
    }

    public func restoreSnapshot(id: String, store: SnapshotStore = SnapshotStore()) async throws {
        guard let snapshot = store.list().first(where: { $0.id == id }) else {
            throw ConfigurationError(
                "That backup is no longer available. Refresh and choose another.")
        }
        do {
            try await DesktopConfiguration.restore(
                snapshot, store: store, integrations: integrations)
        } catch {
            throw ConfigurationError(
                "Restore did not finish; some files may already be restored. \(error.localizedDescription)"
            )
        }
    }

    public func wakeHelpersRegistered() async -> Bool {
        let result = await integrations.execute(Paths.yabai, ["-m", "signal", "--list"])
        guard result.ok,
            let signals = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8))
                as? [[String: Any]]
        else { return false }
        let labels = Set(signals.compactMap { $0["label"] as? String })
        return labels.isSuperset(of: ["macarchy_window_created", "macarchy_refocus_destroyed"])
    }

    public func repairScriptingAddition() async -> CommandResult {
        await ScriptingAddition.repair(execute: integrations.administratorExecute)
    }
}
