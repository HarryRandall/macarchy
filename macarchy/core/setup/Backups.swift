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
    ///
    /// Every stored copy is checked before anything changes, and the current
    /// files are snapshotted first, so edits made since setup can be recovered
    /// from Advanced. Each file is replaced atomically, never removed first.
    func restoreAll(snapshots: SnapshotStore = SnapshotStore()) throws -> [String] {
        let fm = FileManager.default
        let entries = try manifest().entries.sorted { $0.key < $1.key }
        for case (_, .file(let name)) in entries
        where !fm.isReadableFile(atPath: root.appending(path: name).path) {
            throw ConfigurationError(
                "The backup \(name) is missing, so nothing was restored. "
                    + "Your current files are unchanged.")
        }
        try snapshots.capture(
            entries.map { URL(fileURLWithPath: $0.key) }, reason: "before restoring originals")

        var report: [String] = []
        for (path, original) in entries {
            let url = URL(fileURLWithPath: path)
            let isLink = (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
            let present = fm.fileExists(atPath: url.path) || isLink
            switch original {
            case .file(let name):
                try fm.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let staged = url.deletingLastPathComponent()
                    .appending(path: ".\(url.lastPathComponent).macarchy-restore")
                try? fm.removeItem(at: staged)
                try fm.copyItem(at: root.appending(path: name), to: staged)
                if present, !isLink {
                    _ = try fm.replaceItemAt(url, withItemAt: staged)
                } else {
                    if isLink { try fm.removeItem(at: url) }
                    try fm.moveItem(at: staged, to: url)
                }
                report.append("Restored \(Paths.display(url))")
            case .link(let destination):
                let staged = url.deletingLastPathComponent()
                    .appending(path: ".\(url.lastPathComponent).macarchy-restore")
                try? fm.removeItem(at: staged)
                try fm.createSymbolicLink(atPath: staged.path, withDestinationPath: destination)
                // rename(2) replaces the old file or link in one step.
                guard rename(staged.path, url.path) == 0 else {
                    throw ConfigurationError("Could not restore the link \(Paths.display(url))")
                }
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
