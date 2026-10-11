import Foundation

public struct BarConfigurationStore: Sendable {
    public let directory: URL
    public init(directory: URL = Paths.appRoot) { self.directory = directory }
    public var draftURL: URL { directory.appending(path: "menu-bar-draft.json") }
    public var documentURL: URL { directory.appending(path: "settings.json") }

    public func load() throws -> BarConfiguration? {
        if let configuration = try SettingsStore(url: documentURL).read().barConfiguration {
            return configuration
        }
        let legacy = directory.appending(path: "menu-bar.json")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return nil }
        return try JSONDecoder().decode(BarConfiguration.self, from: Data(contentsOf: legacy))
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
        try SettingsStore(url: documentURL).update { settings in
            settings.barConfiguration = configuration
            var values: [String: String] = [:]
            for (key, value) in configuration.geometry {
                if let name = StartupConfiguration.envName(forBarKey: key) { values[name] = value }
            }
            settings.mergeFlat(values)
            settings.itemOrder = []
            settings.itemVisibility = [:]
            settings.itemLabels = [:]
        }
    }
}
