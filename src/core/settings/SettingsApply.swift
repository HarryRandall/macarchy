import Foundation

/// Serialises edits so an older daemon response cannot overwrite a newer setting.
public actor SettingsApply {
    public static let shared = SettingsApply()
    private var tail: Task<CommandResult, Never>?
    public func apply(
        values: [String: String], store: SettingsStore = SettingsStore(),
        command: @escaping @Sendable () async -> CommandResult
    ) async -> CommandResult {
        await enqueue(values: values, store: store, command: command).value
    }

    /// Joins the queue and returns the edit, so a caller can know it is
    /// queued behind earlier edits before any of them finishes.
    func enqueue(
        values: [String: String], store: SettingsStore,
        command: @escaping @Sendable () async -> CommandResult
    ) -> Task<CommandResult, Never> {
        let previous = tail
        let task = Task {
            _ = await previous?.value
            do {
                return try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
                    var proposed = try store.read()
                    proposed.mergeFlat(values)
                    try proposed.validate()
                    let result = await command()
                    guard result.ok else { return result }
                    try store.write(values)
                    return result
                }
            } catch {
                return CommandResult(
                    command: "save settings", status: 1,
                    stderr:
                        "The desktop may have changed, but saving failed: \(error.localizedDescription)"
                )
            }
        }
        tail = task
        return task
    }
}
