import Foundation

/// Serialises edits so an older daemon response cannot overwrite a newer setting.
public actor SettingsApply {
    public static let shared = SettingsApply()
    private var tail: Task<CommandResult, Never>?
    public func apply(
        values: [String: String], store: SettingsStore = SettingsStore(),
        command: @escaping @Sendable () async -> CommandResult
    ) async -> CommandResult {
        let previous = tail
        let task = Task {
            _ = await previous?.value
            do {
                return try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
                    var proposed = try store.read()
                    proposed.mergeLegacy(values)
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
        return await task.value
    }
}
