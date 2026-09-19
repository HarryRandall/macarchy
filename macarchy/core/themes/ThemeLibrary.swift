import Foundation

public struct ThemeLibrary: Sendable {
    public let root: URL
    public init(root: URL = Paths.themesDirectory) { self.root = root }

    public func save(_ theme: Theme, to directory: URL) throws {
        try theme.validate()
        if Theme.load(from: directory) == theme { return }
        try SnapshotStore(root: root.deletingLastPathComponent().appending(path: "snapshots"))
            .capture([directory.appending(path: Theme.fileName)], reason: "edit theme")
        try theme.write(to: directory)
    }

    public func importTheme(from source: URL) throws -> String {
        let theme = try Theme.read(from: source)
        let destination = root.appending(path: theme.name)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ConfigurationError("Theme already installed: \(theme.name)")
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appending(path: ".import-\(UUID())")
        defer { try? FileManager.default.removeItem(at: staging) }
        try copyData(from: source, to: staging)
        try FileManager.default.moveItem(at: staging, to: destination)
        return theme.name
    }

    public func exportTheme(from source: URL, to destination: URL) throws {
        _ = try Theme.read(from: source)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ConfigurationError("Export destination already exists; choose a new folder")
        }
        try copyData(from: source, to: destination)
    }

    private func copyData(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard
            let entries = fm.enumerator(
                at: source, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        else {
            throw ConfigurationError("Cannot read theme folder")
        }
        var files: [(URL, String)] = []
        for case let file as URL in entries {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            guard values.isSymbolicLink != true else {
                throw ConfigurationError("Theme packages cannot contain symbolic links")
            }
            guard values.isRegularFile == true else { continue }
            let relative = String(file.path.dropFirst(source.path.count + 1))
            if file.lastPathComponent == "theme.env" { continue }
            guard
                ["json", "conf", "png", "jpg", "jpeg", "heic", "webp"].contains(
                    file.pathExtension.lowercased())
            else { continue }
            files.append((file, relative))
        }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for (file, relative) in files {
            let target = destination.appending(path: relative)
            try fm.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: file, to: target)
        }
    }
}
