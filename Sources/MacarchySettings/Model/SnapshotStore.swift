import Foundation

/// Point-in-time copies of the files the app writes.
///
/// Every migration phase is gated on being able to get back, so this is
/// load-bearing rather than housekeeping. Pruning is enforced on write: an
/// earlier iteration of this desktop accumulated 809 unpruned wallpaper
/// backups, which is how a safety net becomes a disk problem.
enum SnapshotError: LocalizedError {
    case noMetadata(String)
    var errorDescription: String? {
        switch self {
        case .noMetadata(let id): "Snapshot \(id) has no metadata, so its files can't be placed back."
        }
    }
}

struct SnapshotStore: Sendable {
    let root: URL
    let keep: Int

    init(root: URL = Paths.snapshotsDirectory, keep: Int = 20) {
        self.root = root
        self.keep = keep
    }

    private struct Meta: Codable, Sendable {
        var reason: String
        var paths: [String: String]
    }

    private func meta(for snapshot: Snapshot) -> Meta? {
        guard let data = try? Data(contentsOf: snapshot.url.appending(path: ".meta.json")) else { return nil }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    struct Snapshot: Identifiable, Sendable, Hashable {
        let id: String          // the directory name: an ISO8601 stamp
        let url: URL
        let files: [String]
        let created: Date
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH-mm-ss-SSS"
        f.timeZone = .current
        return f
    }()

    /// Milliseconds alone are not a guarantee, so collisions get a suffix.
    /// An id must be unique or a capture silently overwrites another snapshot.
    private func uniqueDirectory() throws -> (String, URL) {
        let fm = FileManager.default
        let base = Self.stamp.string(from: .now)
        var id = base
        var attempt = 1
        while fm.fileExists(atPath: root.appending(path: id).path) {
            id = "\(base)-\(attempt)"
            attempt += 1
        }
        let url = root.appending(path: id)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return (id, url)
    }

    /// Copies each existing file into a new snapshot directory. Missing files
    /// are skipped rather than failing the whole snapshot — a file that does
    /// not exist yet has nothing worth preserving.
    @discardableResult
    func capture(_ sources: [URL], reason: String) throws -> Snapshot? {
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
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
            mapping[stored] = source.path
            copied.append(stored)
        }

        let meta = try JSONEncoder().encode(Meta(reason: reason, paths: mapping))
        try meta.write(to: directory.appending(path: ".meta.json"), options: .atomic)
        try prune()
        return Snapshot(id: id, url: directory, files: copied, created: .now)
    }

    func list() -> [Snapshot] {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { url in
                let files = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
                    .filter { !$0.hasPrefix(".") }
                    .sorted()
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return Snapshot(id: url.lastPathComponent, url: url, files: files, created: created)
            }
            .sorted { $0.id > $1.id }
    }

    func reason(for snapshot: Snapshot) -> String { meta(for: snapshot)?.reason ?? "" }

    /// Puts files back where they came from. Takes a snapshot of the current
    /// state first, so restoring is itself undoable.
    func restore(_ snapshot: Snapshot) throws {
        let fm = FileManager.default
        guard let meta = meta(for: snapshot) else { throw SnapshotError.noMetadata(snapshot.id) }

        try capture(meta.paths.values.map { URL(fileURLWithPath: $0) },
                    reason: "before restoring \(snapshot.id)")

        for (stored, originalPath) in meta.paths {
            let source = snapshot.url.appending(path: stored)
            guard fm.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: originalPath)
            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
        }
    }

    func prune() throws {
        let all = list()
        guard all.count > keep else { return }
        for snapshot in all.dropFirst(keep) {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }
}
