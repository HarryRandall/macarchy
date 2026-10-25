import Foundation

/// Putting an archive back.
extension OldConfiguration {
    /// Puts back everything an archive holds. Refuses before changing
    /// anything when a path it would restore has been used for something else.
    public static func restore(
        _ name: String, integrations: Integrations = Integrations()
    ) async -> Report {
        let archive = archive(named: name)
        let outcome: Locked
        do {
            outcome = try await OperationLock.run {
                var report = Report(lines: [], commands: [], archive: archive)
                do {
                    let restarts = try await restoreLocked(archive, into: &report)
                    return Locked(report: report, restarts: restarts)
                } catch {
                    report.failure =
                        report.lines.isEmpty
                        ? error.localizedDescription
                        : "Restoring stopped part way: \(error.localizedDescription)"
                    return Locked(report: report, restarts: [])
                }
            }
        } catch {
            return Report(
                lines: [], commands: [], archive: archive, failure: error.localizedDescription)
        }
        var report = outcome.report
        guard report.failure == nil else { return report }
        report.commands = await restart(outcome.restarts, integrations: integrations)
        return report
    }

    static func restoreLocked(_ archive: URL, into report: inout Report) async throws -> [Daemon] {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appending(path: "macarchy-restore-\(UUID())")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let (manifest, files) = try await unpack(archive, into: work)
        let restoring = Restoring(manifest: manifest, files: files)
        let conflicts = restoring.conflicts()
        guard conflicts.isEmpty else {
            throw ConfigurationError(
                "Nothing was restored, because these are in use again: "
                    + conflicts.joined(separator: ", ")
                    + ". Move them aside, then restore again.")
        }
        let rewritten = restoring.entries(.rewritten).map(restoring.place)
            .filter { fm.fileExists(atPath: $0.path) }
        if !rewritten.isEmpty {
            try SnapshotStore().capture(rewritten, reason: "before restoring old configuration")
        }
        try restoring.putBackLauncherFolder(into: &report.lines)
        try restoring.putBackFiles(into: &report.lines)
        try restoring.dropMovedCopies(into: &report.lines)
        let daemons = try restoring.putBackRewritten(into: &report.lines)
            .union(restoring.launcherDaemons)
        let backups = Backups()
        for daemon in [Daemon.yabai, .sketchybar] where daemons.contains(daemon) {
            if DaemonAgents.isInstalled(daemon), Paths.isInstalled(daemon.executableName) {
                try DaemonAgents.install(daemon, backups: backups, report: &report.lines)
            }
        }
        return Daemon.allCases.filter {
            daemons.contains($0) && Paths.isInstalled($0.executableName)
                && DaemonAgents.isInstalled($0)
        }
    }

    /// The steps of putting an unpacked archive back, in order.
    struct Restoring {
        typealias Action = Manifest.Action
        let manifest: Manifest
        let files: URL
        let fm = FileManager.default

        func place(_ path: String) -> URL { Paths.home.appending(path: path) }
        func copy(_ path: String) -> URL { files.appending(path: path) }
        func place(_ entry: Manifest.Entry) -> URL { place(entry.path) }

        func entries(_ action: Action) -> [Manifest.Entry] {
            manifest.entries.filter { $0.action == action }
        }

        /// The daemons whose launchers cleaning up moved.
        var launcherDaemons: Set<Daemon> {
            let names = Set(manifest.launchers.map { place($0).lastPathComponent })
            return Set(StartLauncher.all.filter { names.contains($0.fileName) }.map(\.daemon))
        }

        /// Paths that would be written over although something else is there now.
        func conflicts() -> [String] {
            var found: [String] = []
            for entry in entries(.moved) + entries(.removed) where exists(place(entry)) {
                let url = place(entry)
                let same =
                    !isFolder(url) && !isLink(url)
                    && fm.contentsEqual(atPath: url.path, andPath: copy(entry.path).path)
                if !same { found.append(Paths.display(url)) }
            }
            let allowed = Set(
                manifest.launchers.map { place($0).lastPathComponent } + [".DS_Store"])
            for entry in entries(.link) {
                let url = place(entry)
                let names = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
                if isLink(url) || (exists(url) && !isFolder(url))
                    || !names.allSatisfy(allowed.contains)
                {
                    found.append(Paths.display(url))
                }
            }
            return found
        }

        /// Removes the launchers cleaning up wrote and puts the link back.
        func putBackLauncherFolder(into lines: inout [String]) throws {
            let link = entries(.link).first
            for launcher in manifest.launchers.map(place) where exists(launcher) {
                try fm.removeItem(at: launcher)
                if link == nil { lines.append("Deleted \(Paths.display(launcher))") }
            }
            guard let link else { return }
            let folder = place(link)
            if exists(folder) { try fm.removeItem(at: folder) }
            try fm.createSymbolicLink(atPath: folder.path, withDestinationPath: link.link ?? "")
            lines.append("Put back the link at \(Paths.display(folder))")
        }

        /// Copies back what was deleted or moved, folders first, so the files
        /// inside one that went whole come back with it.
        func putBackFiles(into lines: inout [String]) throws {
            let restored = (entries(.removed) + entries(.moved))
                .sorted {
                    $0.path.split(separator: "/").count < $1.path.split(separator: "/").count
                }
            for entry in restored where !exists(place(entry)) {
                let url = place(entry)
                try fm.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: copy(entry.path), to: url)
                lines.append("Put back \(Paths.display(url))")
            }
        }

        /// Deletes each moved copy nobody has edited since, and the scripts
        /// folder once it is empty.
        func dropMovedCopies(into lines: inout [String]) throws {
            for entry in entries(.moved) {
                guard let to = entry.to.map(place), exists(to) else { continue }
                if let recorded = entry.hash, recorded == hash(of: to) {
                    try fm.removeItem(at: to)
                    lines.append("Deleted the moved copy \(Paths.display(to))")
                } else {
                    lines.append(
                        "Left \(Paths.display(to)), which changed after cleaning up; it is now "
                            + "beside the original")
                }
            }
            if let names = try? fm.contentsOfDirectory(atPath: Paths.scriptsDirectory.path),
                names.allSatisfy({ $0 == ".DS_Store" })
            {
                try fm.removeItem(at: Paths.scriptsDirectory)
            }
        }

        /// Puts each rewritten file back as it was, returning the daemons
        /// that read one of them.
        func putBackRewritten(into lines: inout [String]) throws -> Set<Daemon> {
            var daemons = Set<Daemon>()
            let readers: [(URL, Daemon)] = [
                (written(Paths.skhdrc), .skhd), (StartupConfiguration.yabairc.url, .yabai),
                (StartupConfiguration.sketchybarrc.url, .sketchybar),
                (StartupConfiguration.bordersrc.url, .borders)
            ]
            for entry in entries(.rewritten) {
                let url = written(place(entry))
                let staged = url.deletingLastPathComponent()
                    .appending(path: ".\(url.lastPathComponent).macarchy-restore")
                try? fm.removeItem(at: staged)
                try fm.copyItem(at: copy(entry.path), to: staged)
                if fm.fileExists(atPath: url.path) {
                    _ = try fm.replaceItemAt(url, withItemAt: staged)
                } else {
                    try fm.moveItem(at: staged, to: url)
                }
                lines.append("Put back \(Paths.display(url)) as it was")
                daemons.formUnion(readers.filter { $0.0 == url }.map(\.1))
            }
            return daemons
        }
    }
}
