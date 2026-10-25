import CryptoKit
import Darwin
import Foundation

/// Copying, comparing and deleting what cleaning up archives.
///
/// The old folders can hold files only a running program uses, such as the
/// named pipe a bar helper reads its readings from. Those cannot be copied
/// or zipped, so they are left out of every copy, recorded as skipped and
/// deleted with their folder.
extension OldConfiguration {
    /// What a path was when it was archived, to tell what appeared since.
    enum Fingerprint: Equatable, Sendable {
        case folder
        case file
        case link(String)
        case special
    }

    /// A named pipe, socket or device's kind, or nil for anything else.
    static func specialKind(_ url: URL) -> String? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return nil }
        switch info.st_mode & S_IFMT {
        case S_IFIFO: return "named pipe"
        case S_IFSOCK: return "socket"
        case S_IFCHR, S_IFBLK: return "device"
        default: return nil
        }
    }

    static func fingerprint(_ url: URL) -> Fingerprint? {
        guard exists(url) else { return nil }
        if isLink(url) {
            return .link(
                (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) ?? "")
        }
        if isFolder(url) { return .folder }
        return specialKind(url) == nil ? .file : .special
    }

    /// What a copy holds, by path under the home, and the special files it
    /// left out.
    struct Copied: Sendable {
        var prints: [String: Fingerprint] = [:]
        var skipped: [String] = []
    }

    /// Copies `source` to `target` with names, permissions and extended
    /// attributes, links kept as links, leaving out special files. `key` is
    /// the source's path under the home, as `copied` records it.
    static func copyTree(
        _ source: URL, to target: URL, key: String, into copied: inout Copied
    )
        throws
    {
        let fm = FileManager.default
        guard let print = fingerprint(source) else { return }
        copied.prints[key] = print
        switch print {
        case .special:
            copied.skipped.append(key)
        case .link(let destination):
            try fm.createSymbolicLink(atPath: target.path, withDestinationPath: destination)
        case .file:
            try fm.copyItem(at: source, to: target)
        case .folder:
            try fm.createDirectory(at: target, withIntermediateDirectories: false)
            for name in try fm.contentsOfDirectory(atPath: source.path).sorted() {
                try copyTree(
                    source.appending(path: name), to: target.appending(path: name),
                    key: key + "/" + name, into: &copied)
            }
            // Last, so a folder without write permission can still be filled.
            copyfile(source.path, target.path, nil, copyfile_flags_t(COPYFILE_XATTR))
            if let mode = try? fm.attributesOfItem(atPath: source.path)[.posixPermissions] {
                try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: target.path)
            }
        }
    }

    /// A hash of a folder's names, links and file contents, with `texts`
    /// standing in for the files cleaning up rewrites, by their path inside
    /// it. Special files and Finder's settings are left out, as copies leave
    /// them out and Finder adds them on its own.
    static func treeHash(of folder: URL, replacing texts: [String: String] = [:]) -> String? {
        guard isFolder(folder), let walk = FileManager.default.enumerator(atPath: folder.path)
        else { return nil }
        var paths: [String] = []
        while let relative = walk.nextObject() as? String { paths.append(relative) }
        var digest = SHA256()
        for relative in paths.sorted() {
            let url = folder.appending(path: relative)
            guard url.lastPathComponent != ".DS_Store", let print = fingerprint(url) else {
                continue
            }
            let line: String
            switch print {
            case .special: continue
            case .folder: line = "folder \(relative)"
            case .link(let destination): line = "link \(relative) \(destination)"
            case .file:
                let contents = texts[relative].map { hash(of: $0) } ?? hash(of: url) ?? ""
                line = "file \(relative) \(contents)"
            }
            digest.update(data: Data((line + "\n").utf8))
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Deletes what the archive holds of `url`, keyed by its path under the
    /// home, leaving whatever appeared after archiving and adding it to
    /// `left`. Returns whether `url` itself went.
    @discardableResult
    static func deleteArchived(
        _ url: URL, key: String, archived: [String: Fingerprint], left: inout [URL]
    ) throws -> Bool {
        let fm = FileManager.default
        guard let now = fingerprint(url) else { return true }
        guard let then = archived[key], then == now else {
            left.append(url)
            return false
        }
        guard now == .folder else {
            try fm.removeItem(at: url)
            return true
        }
        var emptied = true
        for name in try fm.contentsOfDirectory(atPath: url.path) {
            emptied =
                try deleteArchived(
                    url.appending(path: name), key: key + "/" + name, archived: archived,
                    left: &left) && emptied
        }
        if emptied { try fm.removeItem(at: url) }
        return emptied
    }

    /// What a special file is, for a report.
    static func describeSpecial(_ url: URL) -> String { specialKind(url) ?? "special file" }
}
