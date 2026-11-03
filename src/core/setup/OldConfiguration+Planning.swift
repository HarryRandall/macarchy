import Foundation

/// Working out what to move, change, delete and leave.
extension OldConfiguration {
    /// Every change cleaning up would make, without making any. With
    /// `checkSyntax` off, rewritten shell is not checked, which is enough to
    /// tell whether there is anything to clean up.
    public static func plan(checkSyntax: Bool = true) async -> Plan {
        if let refusal = refusal() { return Plan(refusal: refusal) }
        var planner = Planner(checkSyntax: checkSyntax)
        return await planner.run()
    }

    /// Why cleaning up has to wait: Macarchy's own configs come first.
    static func refusal() -> String? {
        if LegacyLayout.needsMigration {
            return "Settings from an earlier version have not moved to "
                + "\(Paths.display(Paths.appRoot)) yet. Run setup first; it moves them."
        }
        if !FileManager.default.fileExists(atPath: Paths.settings.path)
            || LegacyLayout.awaitingSetup
        {
            return "Set up Macarchy first: cleaning up relies on the configs setup writes to "
                + "\(Paths.display(Paths.configDirectory))."
        }
        // A daemon Homebrew has removed keeps its old agent until setup runs
        // with it installed again, which it cannot block.
        for daemon in [Daemon.yabai, .sketchybar]
        where DaemonAgents.isInstalled(daemon) && Paths.isInstalled(daemon.executableName) {
            if Doctor.startFile(daemon) != BundledStartLauncher.url(daemon) {
                return
                    "Run setup before cleaning up: the services must use Macarchy's bundled launchers first."
            }
        }
        return nil
    }

    /// One piece of text a check passes or fails as a whole: a shortcut's
    /// command, or a whole file.
    struct Unit {
        let id: String
        let source: Source
        let text: String
    }

    struct Planner {
        let checkSyntax: Bool
        let home = Paths.home.path
        let entries: [Entry]
        let linkedFolders: [URL]
        let kinds: [Entry: Kind]
        let fixed: [Source]
        var moving: Set<Entry> = []
        /// Why each entry that would otherwise move or go stays.
        var pinned: [Entry: String] = [:]
        /// Folders something names as a whole, which stay as they are.
        var folderPins: [String: String] = [:]
        /// Why each moving entry moves.
        var movedBy: [Entry: String] = [:]
        /// Units whose old Macarchy folder cannot be pointed elsewhere.
        var failed: Set<String> = []
        var checked: [String: Bool] = [:]

        init(checkSyntax: Bool) {
            self.checkSyntax = checkSyntax
            let found = OldConfiguration.entries()
            entries = found.entries
            linkedFolders = found.linkedFolders
            kinds = Dictionary(
                uniqueKeysWithValues: entries.map { ($0, OldConfiguration.kind(of: $0)) })
            fixed = OldConfiguration.liveSources()
        }

        var entrySet: Set<Entry> { Set(entries) }

        /// Whether the entry goes unless something keeps it.
        func goes(_ entry: Entry) -> Bool {
            kinds[entry]?.removable == true && pinned[entry] == nil
                && folderPins[entry.folder] == nil
        }

        /// Entries that stay where they are, whose files still run.
        var stayingEntries: [Entry] {
            entries.filter { !moving.contains($0) && !goes($0) && kinds[$0] != .launcher }
        }

        /// The old folders' own files that still matter: what stays, which
        /// may only have the old Macarchy folder pointed elsewhere, and what
        /// moves, which may have anything pointed elsewhere.
        func entrySources() -> [Source] {
            func sources(_ entry: Entry, scope: Source.Scope) -> [Source] {
                OldConfiguration.textFiles(under: entry.url).compactMap { file in
                    guard let text = OldConfiguration.text(of: file) else { return nil }
                    if let shell = OldConfiguration.shell(of: file, text: text) {
                        return Source(url: file, text: text, syntax: .shell(shell), scope: scope)
                    }
                    return Source(url: file, text: text, syntax: .plain, scope: .none)
                }
            }
            return stayingEntries.flatMap { sources($0, scope: .legacyRoot) }
                + moving.sorted().flatMap { sources($0, scope: .all) }
        }

        func units(_ sources: [Source]) -> [Unit] {
            sources.flatMap { source -> [Unit] in
                guard source.syntax == .shortcuts else {
                    return [Unit(id: source.url.path, source: source, text: source.text)]
                }
                return OldConfiguration.commands(in: source.text).enumerated().map {
                    Unit(
                        id: "\(source.url.path)#\($0.offset)", source: source,
                        text: $0.element.command)
                }
            }
        }

        var mappings: [OldPathScanner.Mapping] {
            [.legacyRoot]
                + moving.sorted().map {
                    OldPathScanner.Mapping(
                        old: $0.relative, new: LegacyLayout.rootInShell + "/scripts/" + $0.name)
                }
        }

        mutating func run() async -> Plan {
            pinBarFolder()
            gather()
            for _ in 0..<32 {
                let before = (moving, pinned, folderPins, failed)
                let all = units(fixed + entrySources())
                follow(all)
                await check(all)
                if before == (moving, pinned, folderPins, failed) { break }
            }
            return await finish()
        }

        /// The bundled SketchyBar launcher hands the bar `~/.config/sketchybar`
        /// as `$CONFIG_DIR` while that folder exists. While Macarchy's
        /// sketchybarrc reads that variable, the folder is the bar's.
        mutating func pinBarFolder() {
            guard let bar = fixed.first(where: { $0.url == StartupConfiguration.sketchybarrc.url }),
                OldConfiguration.liveLines(bar.text, comment: "#").contains(where: {
                    $0.contains("CONFIG_DIR")
                })
            else { return }
            folderPins["sketchybar"] =
                "\(Paths.display(bar.url)) reads it through $CONFIG_DIR, which Macarchy's "
                + "launcher sets to this folder"
        }

        /// Everything changeable text runs, followed through the scripts that
        /// would move with it, becomes a candidate to move. What else uses
        /// them is weighed afterwards, once it is known what moves.
        mutating func gather() {
            let present = entrySet
            var grew = true
            while grew {
                grew = false
                let movingSources = entrySources().filter { $0.scope == .all }
                for unit in units(fixed + movingSources) where unit.source.scope == .all {
                    for reference in OldConfiguration.references(
                        in: unit.text, home: home, comment: unit.source.comment)
                    {
                        guard let name = reference.name else { continue }
                        let entry = Entry(folder: reference.folder, name: name)
                        guard present.contains(entry), !moving.contains(entry),
                            pinned[entry] == nil,
                            folderPins[entry.folder] == nil
                        else { continue }
                        if let reason = blocker(entry) {
                            pin(entry, reason)
                            continue
                        }
                        moving.insert(entry)
                        grew = true
                        let source = unit.source.url
                        let inOldFolder = OldConfiguration.homeRelative(source).map { path in
                            OldConfiguration.folderNames.contains {
                                path.hasPrefix(".config/\($0)/")
                            }
                        }
                        movedBy[entry] =
                            inOldFolder == true
                            ? "used by \(Paths.display(source)), which moves too"
                            : "run by \(Paths.display(source))"
                    }
                }
                if !grew { grew = gatherOwnFiles() }
            }
        }

        /// The person's own files nothing names move too, once what is run
        /// has been gathered, so the old folders can go. Whatever uses them
        /// is weighed with everything else.
        mutating func gatherOwnFiles() -> Bool {
            var grew = false
            for entry in entries
            where kinds[entry] == .unknown && !moving.contains(entry)
                && pinned[entry] == nil && folderPins[entry.folder] == nil
            {
                if let reason = blocker(entry) {
                    pin(entry, reason)
                    continue
                }
                moving.insert(entry)
                movedBy[entry] =
                    "yours, though nothing Macarchy knows of runs it; it moves so "
                    + "\(Paths.display(OldConfiguration.folder(entry.folder))) can go"
                grew = true
            }
            return grew
        }

        /// Keeps in place what anything that is not changed uses, and every
        /// folder something names as a whole.
        mutating func follow(_ units: [Unit]) {
            let present = entrySet
            for unit in units {
                let label = Paths.display(unit.source.url)
                for reference in OldConfiguration.references(
                    in: unit.text, home: home, comment: unit.source.comment)
                {
                    guard let name = reference.name else {
                        if folderPins[reference.folder] == nil {
                            folderPins[reference.folder] = "\(label) names the folder as a whole"
                        }
                        continue
                    }
                    let entry = Entry(folder: reference.folder, name: name)
                    guard present.contains(entry), pinned[entry] == nil else { continue }
                    if unit.source.scope != .all || failed.contains(unit.id) {
                        pin(entry, "\(label) uses it, and cleanup does not change that file")
                    }
                }
            }
            for entry in entries where folderPins[entry.folder] != nil && pinned[entry] == nil {
                pin(entry, folderPins[entry.folder] ?? "")
            }
        }

        mutating func pin(_ entry: Entry, _ reason: String) {
            moving.remove(entry)
            pinned[entry] = reason
        }

        /// Why an entry something runs cannot move.
        func blocker(_ entry: Entry) -> String? {
            if kinds[entry] == .launcher { return "Macarchy's launcher" }
            if OldConfiguration.isLink(entry.url) {
                return "a link, which could stop leading where it does if it moved"
            }
            if OldConfiguration.exists(entry.destination) {
                return "\(Paths.display(entry.destination)) already exists"
            }
            if moving.contains(where: { $0.name == entry.name }) {
                return "another file called \(entry.name) moves to "
                    + Paths.display(Paths.scriptsDirectory)
            }
            return nil
        }

        /// Checks each changed unit still parses. A unit that does not keeps
        /// what it runs in place; one that still does not keeps its text.
        mutating func check(_ units: [Unit]) async {
            // A path the scanner leaves as written, such as one in single
            // quotes, would stop working if what it names moved.
            for unit in units where unit.source.scope == .all && !failed.contains(unit.id) {
                let left = OldConfiguration.references(
                    in: rewrite(unit).text, home: home, comment: unit.source.comment)
                for reference in left {
                    guard let name = reference.name else { continue }
                    let entry = Entry(folder: reference.folder, name: name)
                    guard moving.contains(entry) else { continue }
                    pin(
                        entry,
                        "\(Paths.display(unit.source.url)) names it in a way cleanup cannot "
                            + "change, such as inside single quotes")
                }
            }
            for unit in units where checkSyntax && !failed.contains(unit.id) {
                let rewritten = rewrite(unit)
                guard rewritten.changed > 0, let shell = shell(of: unit) else { continue }
                let key = shell + "\u{0}" + rewritten.text
                let passes: Bool
                if let known = checked[key] {
                    passes = known
                } else {
                    passes = await Setup.syntaxProblem(rewritten.text, shell: shell) == nil
                    checked[key] = passes
                }
                guard !passes else { continue }
                let named = OldConfiguration.references(
                    in: unit.text, home: home, comment: unit.source.comment
                ).compactMap { reference in
                    reference.name.map { Entry(folder: reference.folder, name: $0) }
                }
                .filter { moving.contains($0) }
                if named.isEmpty {
                    failed.insert(unit.id)
                } else {
                    for entry in named {
                        pin(
                            entry,
                            "\(Paths.display(unit.source.url)) runs it in a way that would not "
                                + "parse once pointed at the new place")
                    }
                }
            }
        }

        func shell(of unit: Unit) -> String? {
            switch unit.source.syntax {
            case .shortcuts: "/bin/bash"
            case .shell(let shell): shell
            default: nil
            }
        }

        /// A unit's text with what may change in it pointed at the new places.
        func rewrite(_ unit: Unit) -> (text: String, changed: Int) {
            guard !failed.contains(unit.id) else { return (unit.text, 0) }
            switch (unit.source.syntax, unit.source.scope) {
            case (_, .none), (.plain, _): return (unit.text, 0)
            case (.lua, _): return OldConfiguration.rewritingLua(unit.text, home: home)
            case (.ghostty, _): return OldConfiguration.rewritingGhostty(unit.text, home: home)
            case (_, .all):
                return LegacyLayout.rewritingOldPaths(unit.text, home: home, mappings: mappings)
            case (_, .legacyRoot):
                return LegacyLayout.rewritingOldPaths(
                    unit.text, home: home, mappings: [.legacyRoot])
            }
        }
    }
}

extension OldConfiguration {
    /// Each logical line of skhd text, split before its command. Lines
    /// without a command, such as comments, have an empty one.
    static func commands(in text: String) -> [(prefix: String, command: String)] {
        let lines = text.components(separatedBy: "\n")
        var result: [(String, String)] = []
        var start = 0
        while start < lines.count {
            let end = SkhdConfig.logicalEnd(lines, from: start)
            let logical = lines[start...end].joined(separator: "\n")
            start = end + 1
            guard let colon = LegacyLayout.commandStart(in: logical) else {
                result.append((logical, ""))
                continue
            }
            result.append((String(logical[..<colon]), String(logical[colon...])))
        }
        return result
    }
}
