import Foundation

/// Point-in-time copies of the files the app writes.
///
/// Every migration phase is gated on being able to get back, so this is
/// load-bearing rather than housekeeping. Pruning is enforced on write: an
/// earlier iteration of this desktop accumulated 809 unpruned wallpaper
/// backups, which is how a safety net becomes a disk problem.
public enum SnapshotError: LocalizedError {
    case noMetadata(String)
    public var errorDescription: String? {
        switch self {
        case .noMetadata(let id):
            "Snapshot \(id) has no metadata, so its files can't be placed back."
        }
    }
}

public struct SnapshotStore: Sendable {
    public let root: URL
    public let keep: Int

    public init(root: URL = Paths.snapshotsDirectory, keep: Int = 20) {
        self.root = root
        self.keep = keep
    }

    private struct Meta: Codable, Sendable {
        public var reason: String
        public var paths: [String: String]
    }

    private func meta(for snapshot: Snapshot) -> Meta? {
        guard let data = try? Data(contentsOf: snapshot.url.appending(path: ".meta.json")) else {
            return nil
        }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    public struct Snapshot: Identifiable, Sendable, Hashable {
        public let id: String  // the directory name: an ISO8601 stamp
        public let url: URL
        public let files: [String]
        public let created: Date
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS"
        formatter.timeZone = .current
        return formatter
    }()

    /// Milliseconds alone are not a guarantee, so collisions get a suffix.
    /// An id must be unique or a capture silently overwrites another snapshot.
    private func uniqueDirectory() throws -> (String, URL) {
        let fm = FileManager.default
        let id =
            Self.stamp.string(from: .now) + "-"
            + String(format: "%.0f", Date().timeIntervalSince1970 * 1_000_000_000) + "-"
            + UUID().uuidString
        let url = root.appending(path: id)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return (id, url)
    }

    /// Copies each existing file into a new snapshot directory. Missing files
    /// are skipped rather than failing the whole snapshot — a file that does
    /// not exist yet has nothing worth preserving.
    @discardableResult
    public func capture(_ sources: [URL], reason: String) throws -> Snapshot? {
        let fm = FileManager.default
        let present = sources.filter { fm.fileExists(atPath: $0.path) }
        guard !present.isEmpty else { return nil }

        let (id, directory) = try uniqueDirectory()

        var copied: [String] = []
        var mapping: [String: String] = [:]
        for (index, source) in present.enumerated() {
            // Numbered stored names, with the real path recorded separately, so
            // nothing depends on round-tripping a path through a filename.
            let stored = "\(index)-\(source.lastPathComponent)"
            let destination = directory.appending(path: stored)
            try fm.copyItem(at: source, to: destination)
            mapping[stored] = source.path
            copied.append(stored)
        }

        let meta = try JSONEncoder().encode(Meta(reason: reason, paths: mapping))
        try meta.write(to: directory.appending(path: ".meta.json"), options: .atomic)
        try prune()
        return Snapshot(id: id, url: directory, files: copied, created: .now)
    }

    public func list() -> [Snapshot] {
        let fm = FileManager.default
        let entries =
            (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey]))
            ?? []
        return
            entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { url in
                let files = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
                    .filter { !$0.hasPrefix(".") }
                    .sorted()
                let created =
                    (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
                    ?? .distantPast
                return Snapshot(id: url.lastPathComponent, url: url, files: files, created: created)
            }
            .sorted { $0.id > $1.id }
    }

    public func reason(for snapshot: Snapshot) -> String { meta(for: snapshot)?.reason ?? "" }

    /// Where each file in the snapshot came from.
    public func originalPaths(of snapshot: Snapshot) -> [String] {
        meta(for: snapshot).map { Array($0.paths.values).sorted() } ?? []
    }

    /// Puts files back where they came from. Takes a snapshot of the current
    /// state first, so restoring is itself undoable.
    /// Restores under the desktop lock, so a concurrent apply cannot write
    /// over the restored files halfway through.
    public func restoreLocked(_ snapshot: Snapshot) async throws {
        try await OperationLock.run { try restore(snapshot) }
    }

    public func restore(_ snapshot: Snapshot) throws {
        let fm = FileManager.default
        guard let meta = meta(for: snapshot) else { throw SnapshotError.noMetadata(snapshot.id) }

        // Read every source before capture can prune the selected snapshot.
        // Missing or unreadable files abort before any destination is changed.
        let contents = try meta.paths.sorted { $0.key < $1.key }.map { stored, original in
            let source = snapshot.url.appending(path: stored)
            let data = try Data(contentsOf: source)
            let attributes = try fm.attributesOfItem(atPath: source.path)
            return (URL(fileURLWithPath: original), data, attributes[.posixPermissions])
        }
        try capture(contents.map { $0.0 }, reason: "before restoring \(snapshot.id)")
        for (destination, data, permissions) in contents {
            try fm.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            if let permissions {
                try fm.setAttributes(
                    [.posixPermissions: permissions], ofItemAtPath: destination.path)
            }
        }
    }

    public func prune() throws {
        let all = list()
        guard all.count > keep else { return }
        for snapshot in all.dropFirst(keep) {
            try FileManager.default.removeItem(at: snapshot.url)
        }
    }
}
