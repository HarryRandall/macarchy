import Darwin
import Foundation

/// Earlier versions kept everything in `~/.config/macarchy`. The first run of
/// this version moves that folder into Application Support whole, so settings,
/// themes and history carry over, and leaves a link in its place. The link
/// stays until uninstall: startup files and shortcuts from the earlier version,
/// and the person's own scripts, may still name the old folder.
///
/// Whether to move is decided by the data, not by whether the new folder
/// exists: a bar script or a command that runs first can create the new
/// folder, and treating that as "already moved" would leave every setting
/// behind and start from defaults.
public enum LegacyLayout {
    /// What `move` did.
    public enum Outcome: Sendable, Equatable {
        case nothing
        case moved
        /// The new folder already existed without settings. It was set aside,
        /// the old folder moved into its place, and every file that did not
        /// clash moved back in. `setAside` is the folder still holding what
        /// clashed, or nil when only scratch state was left and it was removed.
        case merged(setAside: URL?)
    }

    /// Entries only Macarchy writes; any of them means the old folder holds
    /// the person's data.
    static let dataEntries = ["settings.json", "themes", "snapshots", "widgets"]

    /// The name a set-aside folder starts with, beside the new folder.
    static let setAsidePrefix = "Macarchy before migration"

    // MARK: - State

    /// Whether the old folder holds Macarchy data and the new one has no
    /// settings yet.
    public static var needsMigration: Bool {
        needsMigration(legacy: Paths.legacyRoot, root: Paths.appRoot)
    }

    static func needsMigration(legacy: URL, root: URL) -> Bool {
        isFolder(legacy) && holdsData(legacy)
            && !FileManager.default.fileExists(atPath: root.appending(path: "settings.json").path)
    }

    /// Whether the old folder still holds settings although the new one has
    /// its own, as happens when an earlier build set up afresh instead of
    /// moving them. Macarchy reads only the new folder, so Doctor says so.
    public static var hasLeftoverData: Bool {
        hasLeftoverData(legacy: Paths.legacyRoot, root: Paths.appRoot)
    }

    static func hasLeftoverData(legacy: URL, root: URL) -> Bool {
        isFolder(legacy) && holdsData(legacy)
            && FileManager.default.fileExists(atPath: root.appending(path: "settings.json").path)
    }

    /// Folders a merge set aside because they still hold files.
    public static var setAsideFolders: [URL] {
        let parent = Paths.appRoot.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        return names.filter { $0.hasPrefix(setAsidePrefix) }.sorted()
            .map { parent.appending(path: $0) }
    }

    /// Whether the old folder is a link, as `move` leaves it.
    public static var linkRemains: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: Paths.legacyRoot.path)) != nil
    }

    /// Whether setup still has to run after the move: the link stands in for
    /// the old folder and setup has not yet written the startup files in
    /// `Paths.configDirectory`.
    public static var awaitingSetup: Bool {
        linkRemains
            && !FileManager.default.fileExists(
                atPath: Paths.configDirectory.appending(path: "yabairc").path)
    }

    // MARK: - Moving

    /// Moves the old folder when it needs moving. Returns whether it moved
    /// anything; a failure leaves both folders as they were, and setup, which
    /// calls `move`, reports why.
    @discardableResult
    public static func migrate() -> Bool {
        ((try? move()) ?? .nothing) != .nothing
    }

    public static func move() throws -> Outcome {
        try move(legacy: Paths.legacyRoot, root: Paths.appRoot)
    }

    static func move(legacy: URL, root: URL) throws -> Outcome {
        guard needsMigration(legacy: legacy, root: root) else { return .nothing }
        let fm = FileManager.default
        let parent = root.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        // The app and the command can both start at once; only one moves.
        return try withLock(on: parent) {
            guard needsMigration(legacy: legacy, root: root) else { return .nothing }
            var aside: URL?
            if exists(root) {
                let place = parent.appending(path: "\(setAsidePrefix) \(stamp())")
                try fm.moveItem(at: root, to: place)
                aside = place
            }
            do {
                try fm.moveItem(at: legacy, to: root)
            } catch {
                if let aside { try? fm.moveItem(at: aside, to: root) }
                throw ConfigurationError(
                    "Could not move \(Paths.display(legacy)) to \(Paths.display(root)): "
                        + "\(error.localizedDescription). Nothing was changed.")
            }
            // The data is in place either way; without the link, files from
            // the earlier version stop finding the app until setup rewrites them.
            try? fm.createSymbolicLink(atPath: legacy.path, withDestinationPath: root.path)
            relocateSnapshots(in: root, legacy: legacy)
            guard let aside else { return .moved }
            return .merged(setAside: mergeLeftovers(from: aside, into: root))
        }
    }

    /// Moves every file from `aside` that `root` lacks, then removes `aside`
    /// when only scratch state and locks are left in it. Returns `aside` when
    /// it still holds something worth keeping.
    static func mergeLeftovers(from aside: URL, into root: URL) -> URL? {
        let fm = FileManager.default
        for relative in files(in: aside) {
            let file = aside.appending(path: relative)
            let target = root.appending(path: relative)
            if exists(target) {
                // The same file on both sides, such as the app link, is not a clash.
                if same(file, target) { try? fm.removeItem(at: file) }
                continue
            }
            try? fm.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.moveItem(at: file, to: target)
        }
        let kept = files(in: aside).filter { relative in
            !relative.hasPrefix("state/") && !relative.hasSuffix(".lock")
        }
        guard kept.isEmpty else { return aside }
        try? fm.removeItem(at: aside)
        return nil
    }

    /// Points each snapshot's record at where its files live now, so
    /// restoring one taken before the move changes the files Macarchy uses.
    /// The original record is kept beside it.
    static func relocateSnapshots(in root: URL, legacy: URL) {
        let fm = FileManager.default
        let snapshots = root.appending(path: "snapshots")
        let home = legacy.deletingLastPathComponent().deletingLastPathComponent()
        for name in (try? fm.contentsOfDirectory(atPath: snapshots.path)) ?? [] {
            let meta = snapshots.appending(path: name).appending(path: ".meta.json")
            guard let data = try? Data(contentsOf: meta),
                var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let paths = object["paths"] as? [String: String]
            else { continue }
            let moved = paths.mapValues {
                SnapshotStore.currentLocation(of: $0, home: home, root: root, startupFiles: true)
            }
            guard moved != paths else { continue }
            object["paths"] = moved
            guard
                let updated = try? JSONSerialization.data(
                    withJSONObject: object, options: [.sortedKeys])
            else { continue }
            let original = meta.deletingLastPathComponent().appending(path: ".meta.legacy.json")
            if !fm.fileExists(atPath: original.path) { try? data.write(to: original) }
            try? updated.write(to: meta, options: .atomic)
        }
    }

    /// Removes the link at uninstall, when it is the one `move` left.
    static func removeLink() throws -> Bool {
        guard
            let destination = try? FileManager.default.destinationOfSymbolicLink(
                atPath: Paths.legacyRoot.path),
            URL(fileURLWithPath: destination).standardizedFileURL.path
                == Paths.appRoot.standardizedFileURL.path
        else { return false }
        try FileManager.default.removeItem(at: Paths.legacyRoot)
        return true
    }

    // MARK: - Helpers

    private static func holdsData(_ folder: URL) -> Bool {
        dataEntries.contains { exists(folder.appending(path: $0)) }
    }

    private static func isFolder(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
        let link = (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
        return exists && directory.boolValue && !link
    }

    /// Present as a file, a folder or a link, even a broken one.
    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    /// The relative path of everything under `folder` that is not a folder,
    /// links included. A linked folder, such as the app link, is never entered.
    private static func files(in folder: URL) -> [String] {
        guard let walk = FileManager.default.enumerator(atPath: folder.path) else { return [] }
        var found: [String] = []
        while let relative = walk.nextObject() as? String {
            var info = stat()
            guard lstat(folder.appending(path: relative).path, &info) == 0 else { continue }
            switch info.st_mode & S_IFMT {
            case S_IFDIR: continue
            case S_IFLNK:
                walk.skipDescendants()
                found.append(relative)
            default: found.append(relative)
            }
        }
        return found
    }

    private static func same(_ first: URL, _ second: URL) -> Bool {
        let fm = FileManager.default
        if let one = try? fm.destinationOfSymbolicLink(atPath: first.path) {
            return one == (try? fm.destinationOfSymbolicLink(atPath: second.path))
        }
        return fm.contentsEqual(atPath: first.path, andPath: second.path)
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: .now)
    }

    /// A short exclusive lock on a folder, so it leaves no lock file behind.
    private static func withLock<Value>(on folder: URL, _ body: () throws -> Value) throws -> Value
    {
        let descriptor = open(folder.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw ConfigurationError("Cannot open \(Paths.display(folder)) to move settings")
        }
        defer { close(descriptor) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, ContinuousClock.now < deadline else {
                throw ConfigurationError(
                    "Another copy of Macarchy is moving \(Paths.display(Paths.legacyRoot)); "
                        + "try again")
            }
            usleep(10_000)
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
