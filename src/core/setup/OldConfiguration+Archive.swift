import CryptoKit
import Foundation

/// The zip cleaning up writes before it changes anything, and putting it back.
extension OldConfiguration {
    /// What the archive holds and how each path was changed, by path under
    /// the home. Its files are in the archive under `files/`.
    struct Manifest: Codable, Equatable {
        enum Action: String, Codable {
            case moved, removed, rewritten
            /// The launcher folder was a link to `link`.
            case link
        }

        struct Entry: Codable, Equatable {
            var path: String
            var action: Action
            /// Where a moved entry went.
            var to: String?
            /// A hash of the moved or rewritten file as cleanup left it, so
            /// restoring can tell whether it was edited since.
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

    static func hash(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
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
            let hash = move.texts[""].map { hash(of: $0) } ?? hash(of: move.from)
            entries.append(
                .init(
                    path: try relative(move.from), action: .moved, to: try relative(move.to),
                    hash: isFolder(move.from) ? nil : hash))
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

    /// Copies everything the plan deletes or changes into one zip in
    /// `Paths.backupsDirectory`, checks the zip reads back, and returns it.
    static func writeArchive(_ manifest: Manifest) async throws -> URL {
        let fm = FileManager.default
        let name = archivePrefix + manifest.created
        let work = fm.temporaryDirectory.appending(path: "macarchy-cleanup-\(UUID())")
        defer { try? fm.removeItem(at: work) }
        let staging = work.appending(path: name)
        let files = staging.appending(path: "files")
        try fm.createDirectory(at: files, withIntermediateDirectories: true)
        // Folders first, so a file inside one that goes whole is not copied twice.
        let copied = manifest.entries.filter { $0.action != .link }
            .sorted { $0.path.split(separator: "/").count < $1.path.split(separator: "/").count }
        for entry in copied {
            let source = Paths.home.appending(path: entry.path)
            let copy = files.appending(path: entry.path)
            guard exists(source), !exists(copy) else { continue }
            try fm.createDirectory(
                at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: copy)
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
        // -y keeps links as links; zip keeps each file's permissions.
        let zipped = await CommandRunner.run(
            "/usr/bin/zip", ["-r", "-y", "-q", archive.path, name], timeout: 120, directory: work)
        let tested = await CommandRunner.run("/usr/bin/unzip", ["-t", "-q", archive.path])
        guard zipped.ok, tested.ok, exists(archive) else {
            try? fm.removeItem(at: archive)
            throw ConfigurationError(
                "Could not archive the old configuration, so nothing was changed: "
                    + (zipped.ok ? tested.summary : zipped.summary))
        }
        return archive
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
        let unzipped = await CommandRunner.run(
            "/usr/bin/unzip", ["-q", archive.path, "-d", folder.path], timeout: 120)
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
