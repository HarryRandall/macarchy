import Foundation

public struct BarConfigurationStore {
    public let directory: URL
    public init(directory: URL = Paths.appRoot) { self.directory = directory }
    public var draftURL: URL { directory.appending(path: "menu-bar-draft.json") }
    public var documentURL: URL { directory.appending(path: "menu-bar.json") }
    public var scriptURL: URL { directory.appending(path: "menu-bar.sh") }

    public func load() throws -> BarConfiguration? {
        guard FileManager.default.fileExists(atPath: documentURL.path) else { return nil }
        return try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: documentURL))
    }

    public func loadDraft() throws -> BarConfiguration? {
        guard FileManager.default.fileExists(atPath: draftURL.path) else { return nil }
        return try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: draftURL))
    }

    public func saveDraft(_ configuration: BarConfiguration) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(configuration).write(to: draftURL, options: .atomic)
    }

    public func clearDraft() throws {
        if FileManager.default.fileExists(atPath: draftURL.path) {
            try FileManager.default.removeItem(at: draftURL)
        }
    }

    public func save(_ configuration: BarConfiguration) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try? SnapshotStore(root: directory.appending(path: "snapshots")).capture(
            [documentURL, scriptURL], reason: "menu bar components")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: documentURL, options: .atomic)
        try BarCommands.startupScript(configuration).write(
            to: scriptURL, atomically: true, encoding: .utf8)
    }
}
