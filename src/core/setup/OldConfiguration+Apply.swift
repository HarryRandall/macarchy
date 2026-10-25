import Foundation

/// Carrying out a plan, and undoing it from its archive.
extension OldConfiguration {
    /// Cleans up from a fresh plan. Does not throw: a run that stops part way
    /// still reports what it changed, and the archive puts it back.
    public static func apply(integrations: Integrations = Integrations()) async -> Report {
        let outcome: Locked
        do {
            outcome = try await OperationLock.run {
                var report = Report(lines: [], commands: [])
                do {
                    let restarts = try await applyLocked(into: &report)
                    return Locked(report: report, restarts: restarts)
                } catch {
                    report.failure =
                        report.lines.isEmpty
                        ? error.localizedDescription
                        : "Cleaning up stopped part way: \(error.localizedDescription)"
                            + (report.archive.map {
                                " Everything it changed is in \(Paths.display($0)); put it back "
                                    + "with macarchy cleanup --restore \($0.lastPathComponent)."
                            } ?? "")
                    return Locked(report: report, restarts: [])
                }
            }
        } catch {
            return Report(lines: [], commands: [], failure: error.localizedDescription)
        }
        var report = outcome.report
        guard report.failure == nil else { return report }
        report.commands = await restart(outcome.restarts, integrations: integrations)
        return report
    }

    /// What a step under the desktop lock did, and the daemons to restart
    /// once the lock is released.
    struct Locked: Sendable {
        var report: Report
        var restarts: [Daemon]
    }

    /// Each step adds its line as soon as it has changed something.
    static func applyLocked(into report: inout Report) async throws -> [Daemon] {
        let plan = await plan()
        if let refusal = plan.refusal { throw ConfigurationError(refusal) }
        guard plan.hasChanges else {
            report.lines.append("Nothing to clean up.")
            report.lines += plan.kept.map { "Left \(Paths.display($0.path)): \($0.reason)" }
            return []
        }
        let fm = FileManager.default
        let archive = try await writeArchive(try manifest(for: plan))
        report.archive = archive
        report.lines.append(
            "Archived everything below in \(Paths.display(archive)). Put it back with: "
                + "macarchy cleanup --restore \(archive.lastPathComponent)")
        let changed = plan.rewrites.map(\.file).filter { fm.fileExists(atPath: $0.path) }
        if !changed.isEmpty {
            try SnapshotStore().capture(changed, reason: "before cleaning up old configuration")
        }

        for move in plan.moves {
            try fm.createDirectory(at: Paths.scriptsDirectory, withIntermediateDirectories: true)
            try fm.copyItem(at: move.from, to: move.to)
            for (relative, text) in move.texts.sorted(by: { $0.key < $1.key }) {
                try write(text, to: relative.isEmpty ? move.to : move.to.appending(path: relative))
            }
            report.lines.append(
                "Moved \(Paths.display(move.from)) to \(Paths.display(move.to))"
                    + (move.changed == 0
                        ? "" : ", pointing \(count(move.changed)) in it at the new places"))
        }
        for rewrite in plan.rewrites {
            try write(rewrite.text, to: rewrite.file)
            report.lines.append(
                "Pointed \(count(rewrite.changed)) in \(Paths.display(rewrite.file)) at the new "
                    + "places")
        }

        let backups = Backups()
        if plan.replacedLink != nil {
            try fm.removeItem(at: Paths.launcherDirectory)
            try fm.createDirectory(at: Paths.launcherDirectory, withIntermediateDirectories: true)
            report.lines.append(
                "Replaced the link at \(Paths.display(Paths.launcherDirectory)) with a folder "
                    + "for Macarchy's launchers")
        }
        for moved in plan.launchers {
            guard let launcher = StartLauncher.all.first(where: { $0.daemon == moved.daemon })
            else { continue }
            report.lines += try launcher.place(at: launcher.newURL, backups: backups)
            try fm.removeItem(at: moved.from)
            report.lines.append("Deleted \(Paths.display(moved.from))")
            if DaemonAgents.isInstalled(moved.daemon) {
                try DaemonAgents.install(moved.daemon, backups: backups, report: &report.lines)
            }
        }

        for move in plan.moves where exists(move.from) {
            try fm.removeItem(at: move.from)
        }
        for item in plan.removals where exists(item.path) {
            try fm.removeItem(at: item.path)
            report.lines.append("Deleted \(Paths.display(item.path))")
        }
        report.lines += plan.kept.map { "Left \(Paths.display($0.path)): \($0.reason)" }
        return plan.restarts
    }

    static func count(_ number: Int) -> String { number == 1 ? "1 path" : "\(number) paths" }

    /// Writes through a link and keeps the file's permissions.
    static func write(_ text: String, to url: URL) throws {
        let fm = FileManager.default
        let target = written(url)
        let permissions = try? fm.attributesOfItem(atPath: target.path)[.posixPermissions]
        try text.write(to: target, atomically: true, encoding: .utf8)
        if let permissions {
            try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path)
        }
    }

    /// Restarts the daemons whose files changed, through the same path as
    /// the app's Restart.
    static func restart(_ daemons: [Daemon], integrations: Integrations) async -> [CommandResult] {
        var results: [CommandResult] = []
        for daemon in daemons {
            results.append(await Setup.startService(daemon, integrations: integrations))
        }
        return results
    }
}

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
            return Report(lines: [], commands: [], archive: archive, failure: error.localizedDescription)
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
        let home = Paths.home
        func place(_ path: String) -> URL { home.appending(path: path) }
        func copy(_ path: String) -> URL { files.appending(path: path) }

        var conflicts: [String] = []
        for entry in manifest.entries {
            let url = place(entry.path)
            switch entry.action {
            case .moved, .removed:
                guard exists(url) else { continue }
                if !isFolder(url), !isLink(url), fm.contentsEqual(atPath: url.path, andPath: copy(entry.path).path) {
                    continue
                }
                conflicts.append(Paths.display(url))
            case .link:
                let allowed = Set(manifest.launchers.map { place($0).lastPathComponent } + [".DS_Store"])
                if isLink(url) || (exists(url) && !isFolder(url)) {
                    conflicts.append(Paths.display(url))
                } else if let names = try? fm.contentsOfDirectory(atPath: url.path),
                    !names.allSatisfy(allowed.contains)
                {
                    conflicts.append(Paths.display(url))
                }
            case .rewritten: continue
            }
        }
        guard conflicts.isEmpty else {
            throw ConfigurationError(
                "Nothing was restored, because these are in use again: "
                    + conflicts.joined(separator: ", ")
                    + ". Move them aside, then restore again.")
        }

        let rewritten = manifest.entries.filter { $0.action == .rewritten }.map { place($0.path) }
            .filter { fm.fileExists(atPath: $0.path) }
        if !rewritten.isEmpty {
            try SnapshotStore().capture(rewritten, reason: "before restoring old configuration")
        }
        var daemons = Set<Daemon>()
        for entry in manifest.entries where entry.action == .link {
            let folder = place(entry.path)
            for launcher in manifest.launchers where exists(place(launcher)) {
                try fm.removeItem(at: place(launcher))
            }
            if exists(folder) { try fm.removeItem(at: folder) }
            try fm.createSymbolicLink(atPath: folder.path, withDestinationPath: entry.link ?? "")
            report.lines.append("Put back the link at \(Paths.display(folder))")
        }
        if manifest.entries.allSatisfy({ $0.action != .link }) {
            for launcher in manifest.launchers where exists(place(launcher)) {
                try fm.removeItem(at: place(launcher))
                report.lines.append("Deleted \(Paths.display(place(launcher)))")
            }
        }
        for launcher in manifest.launchers {
            let name = place(launcher).lastPathComponent
            daemons.formUnion(StartLauncher.all.filter { $0.fileName == name }.map(\.daemon))
        }
        // Folders first, so the files inside one that went whole come back with it.
        let restored = manifest.entries.filter { $0.action == .removed || $0.action == .moved }
            .sorted { $0.path.split(separator: "/").count < $1.path.split(separator: "/").count }
        for entry in restored where !exists(place(entry.path)) {
            let url = place(entry.path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: copy(entry.path), to: url)
            report.lines.append("Put back \(Paths.display(url))")
        }
        for entry in manifest.entries where entry.action == .moved {
            guard let to = entry.to.map(place), exists(to) else { continue }
            if let recorded = entry.hash, recorded == hash(of: to) {
                try fm.removeItem(at: to)
                report.lines.append("Deleted the moved copy \(Paths.display(to))")
            } else {
                report.lines.append(
                    "Left \(Paths.display(to)), which changed after cleaning up; it is now "
                        + "beside the original")
            }
        }
        if let names = try? fm.contentsOfDirectory(atPath: Paths.scriptsDirectory.path),
            names.allSatisfy({ $0 == ".DS_Store" })
        {
            try fm.removeItem(at: Paths.scriptsDirectory)
        }
        for entry in manifest.entries where entry.action == .rewritten {
            let url = written(place(entry.path))
            let staged = url.deletingLastPathComponent()
                .appending(path: ".\(url.lastPathComponent).macarchy-restore")
            try? fm.removeItem(at: staged)
            try fm.copyItem(at: copy(entry.path), to: staged)
            if fm.fileExists(atPath: url.path) {
                _ = try fm.replaceItemAt(url, withItemAt: staged)
            } else {
                try fm.moveItem(at: staged, to: url)
            }
            report.lines.append("Put back \(Paths.display(url)) as it was")
            if url == written(Paths.skhdrc) { daemons.insert(.skhd) }
            if url == StartupConfiguration.yabairc.url { daemons.insert(.yabai) }
            if url == StartupConfiguration.sketchybarrc.url { daemons.insert(.sketchybar) }
            if url == StartupConfiguration.bordersrc.url { daemons.insert(.borders) }
        }
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
}
