import Foundation

/// The originals setup replaced, kept until uninstall.
///
/// Unlike snapshots these are never pruned. They also record files that did
/// not exist and files that were symbolic links, as dotfile managers often
/// make them, so uninstall puts back exactly what was there.
struct Backups {
    let root: URL
    init(root: URL = Paths.backupsDirectory) { self.root = root }

    enum Original: Codable, Equatable {
        case absent
        case file(String)
        case link(String)
    }

    private struct Manifest: Codable {
        var entries: [String: Original] = [:]
    }

    private var manifestURL: URL { root.appending(path: "manifest.json") }

    private func manifest() throws -> Manifest {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return Manifest() }
        do {
            return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            // Treating this as empty would let setup record its own output as
            // the original, so it must stop instead.
            throw ConfigurationError(
                "The backup record is unreadable, so setup stopped to protect your originals: "
                    + error.localizedDescription)
        }
    }

    func hasRecord(for url: URL) -> Bool {
        (try? manifest())?.entries[url.path] != nil
    }

    /// Records each file the first time only, immediately before it is
    /// changed, so a second setup cannot replace the true original.
    func save(_ urls: [URL]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        var current = try manifest()
        for url in urls where current.entries[url.path] == nil {
            if let destination = try? fm.destinationOfSymbolicLink(atPath: url.path) {
                current.entries[url.path] = .link(destination)
            } else if fm.fileExists(atPath: url.path) {
                let name = "\(current.entries.count)-\(url.lastPathComponent)"
                let stored = root.appending(path: name)
                try fm.copyItem(at: url, to: stored)
                current.entries[url.path] = .file(name)
            } else {
                current.entries[url.path] = .absent
            }
        }
        try write(current)
    }

    /// Puts every original back, deletes files that did not exist before, and
    /// clears the record so the next setup starts from what is there then.
    func restoreAll() throws -> [String] {
        let fm = FileManager.default
        var report: [String] = []
        for (path, original) in try manifest().entries.sorted(by: { $0.key < $1.key }) {
            let url = URL(fileURLWithPath: path)
            let present =
                fm.fileExists(atPath: url.path)
                || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
            switch original {
            case .file(let name):
                if present { try fm.removeItem(at: url) }
                try fm.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: root.appending(path: name), to: url)
                report.append("Restored \(Paths.display(url))")
            case .link(let destination):
                if present { try fm.removeItem(at: url) }
                try fm.createSymbolicLink(atPath: url.path, withDestinationPath: destination)
                report.append("Restored the link \(Paths.display(url))")
            case .absent:
                if present {
                    try fm.removeItem(at: url)
                    report.append("Removed \(Paths.display(url))")
                }
            }
        }
        if fm.fileExists(atPath: root.path) {
            let finished = root.deletingLastPathComponent()
                .appending(
                    path: "backups-restored-\(Int(Date().timeIntervalSince1970))-"
                        + UUID().uuidString.prefix(8))
            try fm.moveItem(at: root, to: finished)
        }
        return report
    }

    private func write(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }
}
