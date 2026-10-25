import Foundation

/// Uninstalling after cleaning up. Uninstall restores the files setup
/// backed up, which may run the scripts cleaning up moved and read the old
/// folders it deleted, so it also puts those back from each archive,
/// wherever nothing else is there by then. Macarchy's own launchers stay gone,
/// and so does every moved copy nobody edited since.
extension OldConfiguration {
    /// An archive unpacked into a temporary folder, read before uninstall
    /// moves the backups folder aside.
    struct Unpacked: Sendable {
        let archive: URL
        let manifest: Manifest
        let files: URL
        let work: URL
    }

    /// Every cleanup archive, newest first, unpacked.
    static func unpackArchives() async throws -> [Unpacked] {
        var unpacked: [Unpacked] = []
        for archive in archives {
            let work = FileManager.default.temporaryDirectory
                .appending(path: "macarchy-uninstall-\(UUID())")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            do {
                let (manifest, files) = try await unpack(archive, into: work)
                unpacked.append(
                    Unpacked(archive: archive, manifest: manifest, files: files, work: work))
            } catch {
                try? FileManager.default.removeItem(at: work)
                discard(unpacked)
                throw error
            }
        }
        return unpacked
    }

    static func discard(_ unpacked: [Unpacked]) {
        for archive in unpacked { try? FileManager.default.removeItem(at: archive.work) }
    }

    /// Puts back what cleaning up moved or deleted, after uninstall has
    /// restored setup's backups, which win where both have a file.
    static func putBack(_ unpacked: [Unpacked], into report: inout [String]) throws {
        for archive in unpacked {
            let restoring = Restoring(manifest: archive.manifest, files: archive.files)
            let entries = (restoring.entries(.removed) + restoring.entries(.moved))
                .sorted {
                    $0.path.split(separator: "/").count < $1.path.split(separator: "/").count
                }
            for entry in entries {
                let target = restoring.place(entry)
                if try merge(restoring.copy(entry.path), into: target) {
                    report.append(
                        "Put back \(Paths.display(target)) from \(archive.archive.lastPathComponent)"
                    )
                }
            }
            try restoring.dropMovedCopies(into: &report)
        }
    }

    /// Copies `source` to `target` where nothing is there, entering folders
    /// that are, and leaves out Macarchy's launchers. Returns whether it
    /// copied anything.
    static func merge(_ source: URL, into target: URL) throws -> Bool {
        let fm = FileManager.default
        guard exists(source), !isMacarchysLauncher(source) else { return false }
        if !exists(target) {
            try fm.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: target)
            for file in launchers(under: target) { try fm.removeItem(at: file) }
            return true
        }
        guard isFolder(source), isFolder(target), !isLink(target) else { return false }
        var copied = false
        for name in (try? fm.contentsOfDirectory(atPath: source.path)) ?? [] {
            copied =
                try merge(source.appending(path: name), into: target.appending(path: name))
                || copied
        }
        return copied
    }

    static func isMacarchysLauncher(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix("macarchy-") && name.hasSuffix("rc") && !isLink(url)
            && Daemon.allCases.contains { StartLauncher.isMacarchys(at: url, daemon: $0) }
    }

    private static func launchers(under folder: URL) -> [URL] {
        guard isFolder(folder), let walk = FileManager.default.enumerator(atPath: folder.path)
        else { return [] }
        var found: [URL] = []
        while let relative = walk.nextObject() as? String {
            let url = folder.appending(path: relative)
            if isMacarchysLauncher(url) { found.append(url) }
        }
        return found
    }
}
