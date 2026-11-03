import Darwin
import Foundation

/// What is in the tools' old folders, and what names it.
extension OldConfiguration {
    /// One entry at the top of a tool's old folder: a file, a folder or a link.
    struct Entry: Hashable, Sendable, Comparable {
        let folder: String
        let name: String

        var url: URL { OldConfiguration.folder(folder).appending(path: name) }
        /// The path under the home, as a `Mapping` names it.
        var relative: String { "/.config/\(folder)/\(name)" }
        var destination: URL { Paths.scriptsDirectory.appending(path: name) }

        static func < (lhs: Entry, rhs: Entry) -> Bool {
            let order = OldConfiguration.folderNames
            let left = order.firstIndex(of: lhs.folder) ?? order.count
            let right = order.firstIndex(of: rhs.folder) ?? order.count
            return left == right ? lhs.name < rhs.name : left < right
        }
    }

    /// What an entry is, as far as Macarchy can tell.
    enum Kind: Equatable {
        /// Macarchy's launcher from before the launcher folder.
        case launcher
        /// The tool's startup file, which setup read once.
        case startupFile(generated: Bool)
        case backup
        case empty
        case finderData
        /// Part of the bar SketchyBar ran before Macarchy's widget bar.
        case barFile
        /// A named pipe, socket or device, which a running program made and
        /// which cannot be archived.
        case special(String)
        case unknown

        var removable: Bool {
            switch self {
            case .launcher, .startupFile, .backup, .empty, .finderData, .barFile, .special: true
            case .unknown: false
            }
        }

        func reason(_ entry: Entry) -> String {
            switch self {
            case .launcher:
                "an old launcher; Macarchy now uses its bundled launcher"
            case .startupFile(true):
                "written by an earlier version; Macarchy runs config/\(entry.name) now"
            case .startupFile(false):
                "your config from before Macarchy, which setup read once; Macarchy runs "
                    + "config/\(entry.name) now"
            case .backup: "a backup copy"
            case .empty: "an empty folder"
            case .finderData: "Finder's folder settings"
            case .barFile: "part of the bar SketchyBar ran before; Macarchy's bar replaces it"
            case .special(let kind):
                "a \(kind) a running program made, which cannot be archived, so it is only deleted"
            case .unknown: "nothing Macarchy knows of runs it, so it may be yours to keep"
            }
        }
    }

    /// Names that only a copy kept aside has.
    static let backupMarkers = [
        ".backup", ".bak", ".before-", ".retired", ".orig", ".old", ".macarchy-defaults",
        ".macarchy-restore", ".previous"
    ]

    static func kind(of entry: Entry) -> Kind {
        let url = entry.url
        let name = entry.name
        if name == "macarchy-\(entry.folder)rc",
            let daemon = Daemon(rawValue: entry.folder),
            StartLauncher.isMacarchys(at: url, daemon: daemon)
        {
            return .launcher
        }
        if name == ".DS_Store" { return .finderData }
        if let special = specialKind(url) { return .special(special) }
        if name == "\(entry.folder)rc" { return .startupFile(generated: Setup.isGenerated(url)) }
        let lowered = name.lowercased()
        if backupMarkers.contains(where: { lowered.contains($0) }) || name.hasSuffix("~") {
            return .backup
        }
        if isFolder(url), isEmptyFolder(url) { return .empty }
        if entry.folder == "sketchybar" { return .barFile }
        return .unknown
    }

    /// The entries of each old folder that is a real folder. A folder that
    /// is a link, as dotfiles make it, belongs to the person and is left.
    static func entries() -> (entries: [Entry], linkedFolders: [URL]) {
        var found: [Entry] = []
        var linked: [URL] = []
        for name in folderNames {
            let url = folder(name)
            if isLink(url) {
                linked.append(url)
                continue
            }
            guard isFolder(url) else { continue }
            let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
            found += names.map { Entry(folder: name, name: $0) }
        }
        return (found.sorted(), linked)
    }

    // MARK: - References

    /// A path into an old folder that some text names: one of its entries,
    /// or the folder as a whole when the rest of the path is not written out.
    struct Reference: Hashable, Sendable {
        let folder: String
        let name: String?
    }

    /// Characters a file name is made of, as references are read.
    static let nameCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-+@%,".unicodeScalars)
    /// What makes the rest of a path depend on the shell.
    static let expanding = Set("$*?[{`".unicodeScalars)

    /// The ways a path under the home is written: `~`, `$HOME`, `${HOME}`
    /// or the home folder itself.
    static func homeSpellings(_ home: String) -> [[Unicode.Scalar]] {
        ["~", "$HOME", "${HOME}", home].map { Array($0.unicodeScalars) }
    }

    /// Every old-folder path `text` names outside comments.
    static func references(in text: String, home: String, comment: String?) -> Set<Reference> {
        var found = Set<Reference>()
        for line in liveLines(text, comment: comment) {
            let scalars = Array(line.unicodeScalars)
            for name in folderNames {
                let suffix = Array("/.config/\(name)".unicodeScalars)
                for end in occurrences(of: suffix, in: scalars, home: home) {
                    found.formUnion(
                        reference(after: end, in: scalars, folder: name).map { [$0] } ?? [])
                }
            }
        }
        return found
    }

    /// What follows a folder's path at `end`: an entry, the whole folder, or
    /// nothing when the name only starts the same, as `yabai-old` does.
    private static func reference(
        after end: Int, in scalars: [Unicode.Scalar], folder: String
    )
        -> Reference?
    {
        guard end < scalars.count else { return Reference(folder: folder, name: nil) }
        if scalars[end] != "/" {
            return nameCharacters.contains(scalars[end])
                ? nil : Reference(folder: folder, name: nil)
        }
        var cursor = end + 1
        var name = String.UnicodeScalarView()
        while cursor < scalars.count, nameCharacters.contains(scalars[cursor]) {
            name.append(scalars[cursor])
            cursor += 1
        }
        let dynamic = cursor < scalars.count && expanding.contains(scalars[cursor])
        let written = String(name)
        if written.isEmpty || dynamic || written == "." || written == ".." {
            return Reference(folder: folder, name: nil)
        }
        return Reference(folder: folder, name: written)
    }

    /// Whether `text` names `~/.config/macarchy` outside comments, other
    /// than the launchers that folder holds once it is a real one.
    static func namesLegacyRoot(_ text: String, home: String, comment: String?) -> Bool {
        let suffix = Array("/.config/macarchy".unicodeScalars)
        let launchers = StartLauncher.all.map { Array("/\($0.fileName)".unicodeScalars) }
        for line in liveLines(text, comment: comment) {
            let scalars = Array(line.unicodeScalars)
            for end in occurrences(of: suffix, in: scalars, home: home) {
                if end < scalars.count, scalars[end] != "/", nameCharacters.contains(scalars[end]) {
                    continue
                }
                let launcher = launchers.contains { launcher in
                    let stop = end + launcher.count
                    return stop <= scalars.count && Array(scalars[end..<stop]) == launcher
                        && (stop == scalars.count || !nameCharacters.contains(scalars[stop]))
                }
                if !launcher { return true }
            }
        }
        return false
    }

    /// Where `suffix` ends after a home spelling that starts a path.
    private static func occurrences(
        of suffix: [Unicode.Scalar], in scalars: [Unicode.Scalar], home: String
    ) -> [Int] {
        var ends: [Int] = []
        let spellings = homeSpellings(home)
        var index = 0
        while index < scalars.count {
            let starts = index == 0 || !pathStart.contains(scalars[index - 1])
            if starts {
                for spelling in spellings
                where matches(spelling + suffix, in: scalars, at: index) {
                    ends.append(index + spelling.count + suffix.count)
                    break
                }
            }
            index += 1
        }
        return ends
    }

    /// Characters that cannot come just before a home spelling that starts a path.
    private static let pathStart = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-".unicodeScalars)

    private static func matches(
        _ word: [Unicode.Scalar], in scalars: [Unicode.Scalar], at index: Int
    ) -> Bool {
        index + word.count <= scalars.count && Array(scalars[index..<index + word.count]) == word
    }

    /// Lines outside whole-line comments.
    static func liveLines(_ text: String, comment: String?) -> [Substring] {
        text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            guard let comment else { return true }
            return !line.trimmingCharacters(in: .whitespaces).hasPrefix(comment)
        }
    }

    // MARK: - Files

    /// The shell that reads a script, from its `#!` line or, without one,
    /// its name. Nil for anything else.
    static func shell(of url: URL, text: String) -> String? {
        if let first = text.split(separator: "\n", maxSplits: 1).first, first.hasPrefix("#!") {
            if first.contains("zsh") { return "/bin/zsh" }
            if first.contains("bash") || first.hasSuffix("/sh") || first.hasSuffix(" sh") {
                return "/bin/bash"
            }
            return nil
        }
        switch url.pathExtension {
        case "sh", "bash": return "/bin/bash"
        case "zsh": return "/bin/zsh"
        default: return nil
        }
    }

    /// A text file's contents, or nil for anything binary, large or unreadable.
    static func text(of url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            attributes[.type] as? FileAttributeType == .typeRegular,
            (attributes[.size] as? Int ?? 0) <= 1_000_000,
            let data = try? Data(contentsOf: url), !data.contains(0)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Text files at or under `url`, links below it not followed. A link at
    /// `url` itself, such as a dotfiles folder, is followed.
    static func textFiles(under start: URL, limit: Int = 4000) -> [URL] {
        let url = written(start)
        guard isFolder(url) else { return text(of: url) == nil ? [] : [url] }
        guard let walk = FileManager.default.enumerator(atPath: url.path) else { return [] }
        var files: [URL] = []
        while let relative = walk.nextObject() as? String, files.count < limit {
            let file = url.appending(path: relative)
            // skipDescendants after anything but a folder skips the rest of
            // the folder it is in, so a link is only stepped over.
            if isLink(file) { continue }
            if file.lastPathComponent == ".git" {
                walk.skipDescendants()
                continue
            }
            if text(of: file) != nil { files.append(file) }
        }
        return files
    }

    /// The file a write lands in: where a link leads, or the path itself.
    static func written(_ url: URL) -> URL { isLink(url) ? url.resolvingSymlinksInPath() : url }

    /// The path under the home, without a leading slash, or nil outside it.
    /// Both spellings of a home reached through a link count.
    static func homeRelative(_ url: URL) -> String? {
        let path = url.standardizedFileURL.path
        for home in [Paths.home.standardizedFileURL.path, Paths.home.resolvingSymlinksInPath().path]
        where path.hasPrefix(home + "/") {
            let relative = String(path.dropFirst(home.count + 1))
            return relative.split(separator: "/").contains("..") ? nil : relative
        }
        return nil
    }

    static func isLink(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFLNK
    }

    static func isFolder(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR
    }

    static func exists(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
    }

    /// Empty, or holding only Finder's settings.
    static func isEmptyFolder(_ url: URL) -> Bool {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.allSatisfy { $0 == ".DS_Store" }
    }
}
