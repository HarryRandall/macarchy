import CryptoKit
import Darwin
import Foundation

/// The zip cleaning up writes before it changes anything, and putting it back.
extension OldConfiguration {
    /// What the archive holds and how each path was changed, by path under
    /// the home. Its files are in the archive under `files/`.
    struct Manifest: Codable, Equatable, Sendable {
        enum Action: String, Codable, Sendable {
            case moved, removed, rewritten
            /// The launcher folder was a link to `link`.
            case link
            /// A named pipe, socket or device, which is not in the archive
            /// but was deleted with its folder.
            case skipped
        }

        struct Entry: Codable, Equatable, Sendable {
            var path: String
            var action: Action
            /// Where a moved entry went.
            var to: String?
            /// A hash of the moved or rewritten file as cleanup left it, or
            /// of a moved folder's tree (`treeHash`), so restoring can tell
            /// whether it was edited since.
            var hash: String?
            var link: String?
        }

        var version = 1
        var created: String
        var entries: [Entry]
        /// Launchers written in the launcher folder, by path under the home.
        var launchers: [String]
    }

    static let archivePrefix = "old-configuration-"

    static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: .now)
    }

    /// A regular file's hash, through links. Nil for anything else: reading
    /// a named pipe would wait for a writer.
    static func hash(of url: URL) -> String? {
        var info = stat()
        guard stat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
            let data = try? Data(contentsOf: url)
        else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hash(of text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The manifest for a plan.
    static func manifest(for plan: Plan) throws -> Manifest {
        func relative(_ url: URL) throws -> String {
            guard let path = homeRelative(url) else {
                throw ConfigurationError(
                    "\(Paths.display(url)) is outside your home folder, so it cannot be archived. "
                        + "Nothing was changed.")
            }
            return path
        }
        var entries: [Manifest.Entry] = []
        for move in plan.moves {
            let hash =
                isFolder(move.from)
                ? treeHash(of: move.from, replacing: move.texts)
                : move.texts[""].map { hash(of: $0) } ?? hash(of: move.from)
            entries.append(
                .init(
                    path: try relative(move.from), action: .moved, to: try relative(move.to),
                    hash: hash))
        }
        for rewrite in plan.rewrites {
            entries.append(
                .init(
                    path: try relative(rewrite.file), action: .rewritten,
                    hash: hash(of: rewrite.text)))
        }
        if let link = plan.replacedLink {
            entries.append(
                .init(path: try relative(Paths.launcherDirectory), action: .link, link: link))
        }
        for launcher in plan.launchers {
            entries.append(.init(path: try relative(launcher.from), action: .removed))
        }
        for item in plan.removals {
            entries.append(.init(path: try relative(item.path), action: .removed))
        }
        let launchers = try plan.launchers.map {
            try relative(
                Paths.launcherDirectory.appending(path: "macarchy-\($0.daemon.rawValue)rc"))
        }
        return Manifest(created: stamp(), entries: entries, launchers: launchers)
    }

    /// A written archive: where it is, the manifest it holds and what it
    /// holds of each path, to delete only that.
    struct Written: Sendable {
        let url: URL
        let manifest: Manifest
        let archived: [String: Fingerprint]
    }

    /// Copies everything the plan deletes or changes into one zip in
    /// `Paths.backupsDirectory`, checks the zip reads back, and returns it.
    /// Special files are left out and recorded as skipped. ditto keeps
    /// links, permissions and extended attributes, which zip drops.
    static func writeArchive(_ planned: Manifest) async throws -> Written {
        let fm = FileManager.default
        var manifest = planned
        let name = archivePrefix + manifest.created
        let work = fm.temporaryDirectory.appending(path: "macarchy-cleanup-\(UUID())")
        defer { try? fm.removeItem(at: work) }
        let staging = work.appending(path: name)
        let files = staging.appending(path: "files")
        try fm.createDirectory(at: files, withIntermediateDirectories: true)
        var copied = Copied()
        // Folders first, so a file inside one that goes whole is not copied twice.
        let entries = manifest.entries.filter { $0.action != .link }
            .sorted { $0.path.split(separator: "/").count < $1.path.split(separator: "/").count }
        for entry in entries {
            let source = Paths.home.appending(path: entry.path)
            let copy = files.appending(path: entry.path)
            guard exists(source), copied.prints[entry.path] == nil else { continue }
            try fm.createDirectory(
                at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
            // A rewritten file is put back where its link leads, so the
            // archive holds what the link leads to.
            let read = entry.action == .rewritten ? written(source) : source
            try copyTree(read, to: copy, key: entry.path, into: &copied)
        }
        let listed = Set(manifest.entries.map(\.path))
        for index in manifest.entries.indices
        where copied.skipped.contains(manifest.entries[index].path) {
            manifest.entries[index].action = .skipped
        }
        manifest.entries += copied.skipped.filter { !listed.contains($0) }.map {
            Manifest.Entry(path: $0, action: .skipped)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: staging.appending(path: "manifest.json"))

        try fm.createDirectory(at: Paths.backupsDirectory, withIntermediateDirectories: true)
        var archive = Paths.backupsDirectory.appending(path: name + ".zip")
        var suffix = 2
        while exists(archive) {
            archive = Paths.backupsDirectory.appending(path: "\(name)-\(suffix).zip")
            suffix += 1
        }
        let zipped = await CommandRunner.run(
            "/usr/bin/ditto",
            ["-c", "-k", "--sequesterRsrc", "--keepParent", staging.path, archive.path],
            timeout: 120)
        let tested = await CommandRunner.run("/usr/bin/unzip", ["-t", "-q", archive.path])
        guard zipped.ok, tested.ok, exists(archive) else {
            try? fm.removeItem(at: archive)
            throw ConfigurationError(
                "Could not archive the old configuration, so nothing was changed: "
                    + (zipped.ok ? tested.summary : zipped.summary))
        }
        return Written(url: archive, manifest: manifest, archived: copied.prints)
    }

    /// The archive a person names: a path, or a name in the backups folder.
    static func archive(named name: String) -> URL {
        if name.contains("/") {
            let expanded =
                name.hasPrefix("~/") ? Paths.home.path + name.dropFirst() : name
            return URL(fileURLWithPath: expanded)
        }
        let file = name.hasSuffix(".zip") ? name : name + ".zip"
        return Paths.backupsDirectory.appending(path: file)
    }

    /// The archives cleaning up has written, newest first.
    public static var archives: [URL] {
        let names =
            (try? FileManager.default.contentsOfDirectory(atPath: Paths.backupsDirectory.path))
            ?? []
        return names.filter { $0.hasPrefix(archivePrefix) && $0.hasSuffix(".zip") }.sorted()
            .reversed().map { Paths.backupsDirectory.appending(path: $0) }
    }

    /// The manifest and files of an archive, unpacked into `folder`.
    static func unpack(_ archive: URL, into folder: URL) async throws -> (Manifest, URL) {
        guard FileManager.default.fileExists(atPath: archive.path) else {
            throw ConfigurationError(
                "There is no archive at \(Paths.display(archive)). Archives are in "
                    + "\(Paths.display(Paths.backupsDirectory)).")
        }
        // ditto puts back the extended attributes it sequestered.
        let unzipped = await CommandRunner.run(
            "/usr/bin/ditto", ["-x", "-k", archive.path, folder.path], timeout: 120)
        let top = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        guard unzipped.ok, let name = top.first(where: { $0.hasPrefix(archivePrefix) }) else {
            throw ConfigurationError(
                "\(Paths.display(archive)) could not be read as a cleanup archive. "
                    + unzipped.summary)
        }
        let staging = folder.appending(path: name)
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: staging.appending(path: "manifest.json")))
        // A path that climbs out of the home could write anywhere.
        for path in manifest.entries.map(\.path) + manifest.entries.compactMap(\.to)
            + manifest.launchers
        where path.hasPrefix("/") || path.split(separator: "/").contains("..") || path.isEmpty {
            throw ConfigurationError(
                "\(Paths.display(archive)) names \(path), outside your home folder, so nothing "
                    + "was restored.")
        }
        return (manifest, staging.appending(path: "files"))
    }
}
