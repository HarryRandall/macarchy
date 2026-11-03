import Foundation

/// Cleaning up what earlier versions left outside Macarchy's folder, as an
/// explicit step: `macarchy cleanup` and Advanced → Clean up old configuration.
///
/// Earlier versions wrote startup files into the tools' own folders,
/// `~/.config/yabai`, `skhd`, `borders` and `sketchybar`, where people also
/// keep scripts their shortcuts run, and the move to Application Support
/// left a link at `~/.config/macarchy`. Macarchy reads none of it now. The
/// cleanup moves the person's scripts that something live runs into
/// `Paths.scriptsDirectory` and points every reference at them, removes
/// the old link once nothing reads through it, and deletes the rest. A file something still names in
/// a way it cannot change, and anything it cannot classify, stays where it
/// is and is reported.
///
/// `plan` only reads. `apply` works from a fresh plan under the desktop
/// lock and archives every file it deletes or changes into one zip in
/// `Paths.backupsDirectory` before touching anything, which `restore`
/// puts back.
public enum OldConfiguration {
    /// The tools' own folders, in the order they are reported.
    static let folderNames = ["yabai", "skhd", "borders", "sketchybar"]

    static func folder(_ name: String) -> URL { Paths.home.appending(path: ".config/\(name)") }

    /// What cleaning up would do, or did.
    public struct Plan: Sendable, Equatable {
        public struct Move: Sendable, Equatable {
            public let from: URL
            public let to: URL
            public let reason: String
            /// New contents for files whose references change, by their path
            /// inside the moved entry; an empty path is the entry itself.
            let texts: [String: String]
            let changed: Int
        }

        public struct Rewrite: Sendable, Equatable {
            public let file: URL
            public let changed: Int
            let text: String
        }

        /// A path deleted, or left in place, and why.
        public struct Item: Sendable, Equatable {
            public let path: URL
            public let reason: String
        }

        /// A launcher moved into `Paths.launcherDirectory`.
        public struct Launcher: Sendable, Equatable {
            public let daemon: Daemon
            public let from: URL
        }

        public var moves: [Move] = []
        public var rewrites: [Rewrite] = []
        public var removals: [Item] = []
        public var kept: [Item] = []
        /// Where the link at the launcher folder leads, when it is replaced.
        public var replacedLink: String?
        public var launchers: [Launcher] = []
        public var restarts: [Daemon] = []
        /// Why nothing can be cleaned up yet, such as setup not having run.
        public var refusal: String?

        /// Whether applying would change anything.
        public var hasChanges: Bool {
            !moves.isEmpty || !rewrites.isEmpty || !removals.isEmpty || replacedLink != nil
                || !launchers.isEmpty
        }
    }

    /// One heading of the plan as people read it, shared by the command and
    /// the app.
    public struct Section: Sendable, Equatable {
        public struct Line: Sendable, Equatable {
            public let path: String
            public let detail: String
        }
        public let title: String
        public let lines: [Line]
    }

    /// What `apply` and `restore` did.
    public struct Report: Sendable {
        public var lines: [String]
        public var commands: [CommandResult]
        /// The archive holding everything that was deleted or changed.
        public var archive: URL?
        /// Why it stopped part way; `lines` still says what changed first.
        public var failure: String?
    }
}

extension OldConfiguration.Plan {
    /// The plan under headings, in the order it is carried out.
    public var sections: [OldConfiguration.Section] {
        typealias Line = OldConfiguration.Section.Line
        var sections: [OldConfiguration.Section] = []
        func add(_ title: String, _ lines: [Line]) {
            if !lines.isEmpty { sections.append(.init(title: title, lines: lines)) }
        }
        add(
            "Move into \(Paths.display(Paths.scriptsDirectory)), keeping names and permissions",
            moves.map { Line(path: Paths.display($0.from), detail: $0.reason) })
        add(
            "Point paths at the new places",
            rewrites.map {
                Line(
                    path: Paths.display($0.file),
                    detail: $0.changed == 1 ? "1 path" : "\($0.changed) paths")
            })
        var link: [Line] = []
        if let replacedLink {
            link.append(
                Line(
                    path: Paths.display(Paths.launcherDirectory),
                    detail: "removes the link to "
                        + Paths.display(URL(fileURLWithPath: replacedLink))))
        }
        link += launchers.map {
            Line(
                path: Paths.display(
                    Paths.launcherDirectory.appending(path: "macarchy-\($0.daemon.rawValue)rc")),
                detail: "\($0.daemon.displayName) starts here, moved from \(Paths.display($0.from))"
            )
        }
        add(
            replacedLink == nil
                ? "Move Macarchy's launchers into \(Paths.display(Paths.launcherDirectory))"
                : "Remove the old configuration link at \(Paths.display(Paths.launcherDirectory))",
            link)
        add(
            "Archive, then delete",
            removals.map { Line(path: Paths.display($0.path), detail: $0.reason) })
        add("Leave in place", kept.map { Line(path: Paths.display($0.path), detail: $0.reason) })
        add(
            "Restart",
            restarts.isEmpty
                ? [] : [Line(path: restarts.map(\.displayName).joined(separator: ", "), detail: "")]
        )
        return sections
    }

    /// The plan as the command prints it.
    public var text: String {
        if let refusal { return refusal }
        guard hasChanges else {
            var lines = ["Nothing to clean up."]
            for section in sections {
                lines.append("")
                lines.append(section.title)
                for line in section.lines { lines.append("  \(line.path): \(line.detail)") }
            }
            return lines.joined(separator: "\n")
        }
        var lines = ["Cleaning up old configuration would:"]
        for section in sections {
            lines.append("")
            lines.append(section.title)
            for line in section.lines {
                lines.append("  " + line.path)
                if !line.detail.isEmpty { lines.append("      " + line.detail) }
            }
        }
        lines.append("")
        lines.append(
            "Everything it deletes or changes goes into one archive in "
                + "\(Paths.display(Paths.backupsDirectory)) first.")
        return lines.joined(separator: "\n")
    }
}
