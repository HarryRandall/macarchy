import Foundation

/// The originals setup replaced, kept until uninstall.
///
/// Unlike snapshots these are never pruned, and they also record files that
/// did not exist, so uninstall can remove what setup created instead of
/// leaving an empty startup file behind.
struct Backups {
    let root: URL
    init(root: URL = Paths.backupsDirectory) { self.root = root }

    private struct Manifest: Codable {
        /// Original absolute path to the stored file name, or nil if it did not exist.
        var entries: [String: String?] = [:]
    }

    private var manifestURL: URL { root.appending(path: "manifest.json") }

    private func manifest() throws -> Manifest {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return Manifest() }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    }

    func hasRecord(for url: URL) -> Bool {
        (try? manifest())?.entries.keys.contains(url.path) ?? false
    }

    /// Records each file the first time only, so a second setup cannot
    /// replace the true original with Macarchy's own output.
    func save(_ urls: [URL]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        var current = try manifest()
        for url in urls where current.entries[url.path] == nil {
            guard fm.fileExists(atPath: url.path) else {
                current.entries[url.path] = .some(nil)
                continue
            }
            let name = "\(current.entries.count)-\(url.lastPathComponent)"
            let destination = root.appending(path: name)
            // Copy what a symlink points at; restoring a dangling link helps nobody.
            try Data(contentsOf: url.resolvingSymlinksInPath()).write(to: destination)
            let mode = try fm.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)[
                .posixPermissions]
            if let mode {
                try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: destination.path)
            }
            current.entries[url.path] = .some(name)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(current).write(to: manifestURL, options: .atomic)
    }

    /// Puts every original back and deletes files that did not exist before.
    func restoreAll() throws -> [String] {
        let fm = FileManager.default
        var report: [String] = []
        for (path, stored) in try manifest().entries.sorted(by: { $0.key < $1.key }) {
            let url = URL(fileURLWithPath: path)
            if let stored {
                let source = root.appending(path: stored)
                let attributes = try fm.attributesOfItem(atPath: source.path)
                try Data(contentsOf: source).write(to: url, options: .atomic)
                if let mode = attributes[.posixPermissions] {
                    try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: url.path)
                }
                report.append("Restored \(Paths.display(url))")
            } else if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
                report.append("Removed \(Paths.display(url))")
            }
        }
        return report
    }
}
