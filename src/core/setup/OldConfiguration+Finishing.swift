import Foundation

/// Turning what the planner settled into the plan.
extension OldConfiguration.Planner {
    typealias Plan = OldConfiguration.Plan
    typealias Source = OldConfiguration.Source
    typealias Entry = OldConfiguration.Entry
    typealias Unit = OldConfiguration.Unit

    mutating func finish() async -> Plan {
        var plan = Plan()
        var finalTexts: [(Source, String)] = []
        plan.moves = moves(finalTexts: &finalTexts)
        plan.rewrites = rewrites(finalTexts: &finalTexts)

        let blockers = finalTexts.filter { source, text in
            OldConfiguration.namesLegacyRoot(text, home: home, comment: source.comment)
        }.map { Paths.display($0.0.url) }
        let usable = launcherFolder(blockers: blockers, plan: &plan)

        var relocated: Set<Entry> = []
        var removals: [Plan.Item] = []
        for launcher in StartLauncher.all {
            let entry = Entry(folder: launcher.daemon.rawValue, name: launcher.fileName)
            guard kinds[entry] == .launcher, pinned[entry] == nil else { continue }
            guard usable else {
                pinned[entry] =
                    "Macarchy's launcher, which stays until \(Paths.display(Paths.launcherDirectory)) "
                    + "can hold it"
                continue
            }
            relocated.insert(entry)
            if Paths.isInstalled(launcher.daemon.executableName) {
                plan.launchers.append(.init(daemon: launcher.daemon, from: launcher.legacyURL))
            } else {
                removals.append(
                    .init(
                        path: launcher.legacyURL,
                        reason: "Macarchy's launcher; \(launcher.daemon.displayName) is not "
                            + "installed"))
            }
        }

        for entry in entries where !moving.contains(entry) && goes(entry) {
            removals.append(.init(path: entry.url, reason: kinds[entry]?.reason(entry) ?? ""))
        }
        plan.removals = collapse(removals + plan.launchers.map { .init(path: $0.from, reason: "") })
            .filter { item in !plan.launchers.contains { $0.from == item.path } }
        plan.kept = kept(relocated: relocated)
        if !blockers.isEmpty, OldConfiguration.isLink(Paths.launcherDirectory) {
            plan.kept.insert(
                .init(
                    path: Paths.launcherDirectory,
                    reason: "\(blockers.joined(separator: ", ")) still "
                        + (blockers.count == 1 ? "reads" : "read")
                        + " through this link, in a way cleanup cannot change, so it stays"),
                at: 0)
        }
        plan.restarts = restarts(plan)
        return plan
    }

    /// Each moving entry, with the new text of its scripts.
    func moves(finalTexts: inout [(Source, String)]) -> [Plan.Move] {
        moving.sorted().map { entry in
            var texts: [String: String] = [:]
            var changed = 0
            for file in OldConfiguration.textFiles(under: entry.url) {
                guard let text = OldConfiguration.text(of: file) else { continue }
                let relative = String(file.path.dropFirst(entry.url.path.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let shell = OldConfiguration.shell(of: file, text: text)
                let source = Source(
                    url: file, text: text, syntax: shell.map { .shell($0) } ?? .plain,
                    scope: shell == nil ? .none : .all)
                let rewritten = rewrite(Unit(id: file.path, source: source, text: text))
                if rewritten.changed > 0 {
                    texts[relative] = rewritten.text
                    changed += rewritten.changed
                }
                finalTexts.append((source, rewritten.text))
            }
            return Plan.Move(
                from: entry.url, to: entry.destination,
                reason: movedBy[entry] ?? "run by your configuration", texts: texts,
                changed: changed)
        }
    }

    /// Files outside the moving entries whose paths change.
    func rewrites(finalTexts: inout [(Source, String)]) -> [Plan.Rewrite] {
        let staying = fixed + entrySources().filter { $0.scope != .all }
        return staying.compactMap { source in
            var changed = 0
            let text: String
            if source.syntax == .shortcuts {
                text = OldConfiguration.commands(in: source.text).enumerated().map {
                    let unit = Unit(
                        id: "\(source.url.path)#\($0.offset)", source: source,
                        text: $0.element.command)
                    let rewritten = rewrite(unit)
                    changed += rewritten.changed
                    return $0.element.prefix + rewritten.text
                }.joined(separator: "\n")
            } else {
                let rewritten = rewrite(
                    Unit(id: source.url.path, source: source, text: source.text))
                changed = rewritten.changed
                text = rewritten.text
            }
            finalTexts.append((source, text))
            return changed == 0 ? nil : Plan.Rewrite(file: source.url, changed: changed, text: text)
        }
    }

    /// Whether launchers can go in the launcher folder, deciding whether
    /// the link there is replaced.
    func launcherFolder(blockers: [String], plan: inout Plan) -> Bool {
        let folder = Paths.launcherDirectory
        if OldConfiguration.isLink(folder) {
            guard blockers.isEmpty,
                let destination = try? FileManager.default.destinationOfSymbolicLink(
                    atPath: folder.path)
            else { return false }
            plan.replacedLink = destination
            return true
        }
        if OldConfiguration.exists(folder), !OldConfiguration.isFolder(folder) {
            plan.kept.append(
                .init(
                    path: folder,
                    reason: "a file Macarchy did not make, so its launchers stay in the tools' "
                        + "folders"))
            return false
        }
        return true
    }

    /// A folder left with nothing once cleaned up goes as a whole.
    func collapse(_ removals: [Plan.Item]) -> [Plan.Item] {
        var result: [Plan.Item] = []
        let going = Set(removals.map(\.path.path))
        for name in OldConfiguration.folderNames {
            let folder = OldConfiguration.folder(name)
            let inside = entries.filter { $0.folder == name }
            let mine = removals.filter { $0.path.deletingLastPathComponent().path == folder.path }
            let emptied =
                !inside.isEmpty && folderPins[name] == nil
                && inside.allSatisfy { moving.contains($0) || going.contains($0.url.path) }
            guard emptied else {
                result += mine
                continue
            }
            let moved = inside.filter { moving.contains($0) }.count
            result.append(.init(path: folder, reason: summary(name, moved: moved)))
        }
        let folders = Set(OldConfiguration.folderNames.map { OldConfiguration.folder($0).path })
        result += removals.filter { !folders.contains($0.path.deletingLastPathComponent().path) }
        return result
    }

    /// What a folder that goes as a whole held.
    func summary(_ name: String, moved: Int) -> String {
        let inside = entries.filter { $0.folder == name && !moving.contains($0) }
        var parts: [String] = []
        let startup = inside.filter {
            if case .startupFile = kinds[$0] { return true }
            return false
        }
        parts += startup.map { "the old \($0.name)" }
        if inside.contains(where: { kinds[$0] == .launcher }) {
            parts.append("Macarchy's launcher")
        }
        let backups = inside.filter { kinds[$0] == .backup }.count
        if backups > 0 { parts.append(backups == 1 ? "a backup copy" : "\(backups) backup copies") }
        let empty = inside.filter { kinds[$0] == .empty }.count
        if empty > 0 { parts.append(empty == 1 ? "an empty folder" : "\(empty) empty folders") }
        if inside.contains(where: { kinds[$0] == .barFile }) {
            parts.append("the bar SketchyBar ran before")
        }
        var text =
            parts.isEmpty
            ? "nothing Macarchy reads"
            : parts.dropLast().joined(separator: ", ")
                + (parts.count > 1 ? " and " : "") + (parts.last ?? "")
        if moved > 0 {
            text =
                "once \(moved == 1 ? "1 script moves" : "\(moved) scripts move"), only "
                + text + " is left"
        }
        return text + "; Macarchy reads none of it"
    }

    /// What stays, and why.
    func kept(relocated: Set<Entry>) -> [Plan.Item] {
        var items: [Plan.Item] = []
        for folder in linkedFolders {
            let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: folder.path))
                .map { URL(fileURLWithPath: $0, relativeTo: folder.deletingLastPathComponent()) }
            items.append(
                .init(
                    path: folder,
                    reason:
                        "a link to \(target.map { Paths.display($0.standardizedFileURL) } ?? "a folder"), "
                        + "as dotfiles make it; cleanup leaves what is there"))
        }
        let pinnedFolders = Set(folderPins.keys)
        for name in OldConfiguration.folderNames where pinnedFolders.contains(name) {
            guard entries.contains(where: { $0.folder == name }) else { continue }
            items.append(.init(path: OldConfiguration.folder(name), reason: folderPins[name] ?? ""))
        }
        for entry in entries where !pinnedFolders.contains(entry.folder) {
            if moving.contains(entry) || relocated.contains(entry) || goes(entry) { continue }
            let reason = pinned[entry] ?? kinds[entry]?.reason(entry) ?? ""
            items.append(.init(path: entry.url, reason: reason))
        }
        let earlier = Paths.home.appending(path: ".config/macarchy-settings")
        if FileManager.default.fileExists(atPath: earlier.appending(path: "settings.json").path) {
            items.append(
                .init(
                    path: earlier,
                    reason: "settings from a much earlier Macarchy, which this version never "
                        + "read; check it and delete it yourself"))
        }
        return items
    }

    /// The daemons to restart so they read what changed.
    func restarts(_ plan: Plan) -> [Daemon] {
        var daemons = Set(plan.launchers.map(\.daemon))
        let written = Set(plan.rewrites.map(\.file.path))
        if written.contains(OldConfiguration.written(Paths.skhdrc).path) { daemons.insert(.skhd) }
        let files: [(GeneratedFile, Daemon)] = [
            (StartupConfiguration.yabairc, .yabai),
            (StartupConfiguration.sketchybarrc, .sketchybar),
            (StartupConfiguration.bordersrc, .borders)
        ]
        for (file, daemon) in files where written.contains(file.url.path) { daemons.insert(daemon) }
        return Daemon.allCases.filter {
            daemons.contains($0) && Paths.isInstalled($0.executableName)
                && DaemonAgents.isInstalled($0)
        }
    }
}
