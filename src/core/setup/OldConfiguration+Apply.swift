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

        try moveAndPoint(plan, into: &report.lines)

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
        let bar = OldConfiguration.folder("sketchybar")
        if plan.removals.contains(where: { $0.path.path == bar.path }) {
            report.lines += try noteBarArchive(archive)
        }
        report.lines += plan.kept.map { "Left \(Paths.display($0.path)): \($0.reason)" }
        return plan.restarts
    }

    /// Moves the scripts, then points every file that names them at their new place.
    static func moveAndPoint(_ plan: Plan, into lines: inout [String]) throws {
        let fm = FileManager.default
        for move in plan.moves {
            try fm.createDirectory(at: Paths.scriptsDirectory, withIntermediateDirectories: true)
            try fm.copyItem(at: move.from, to: move.to)
            for (relative, text) in move.texts.sorted(by: { $0.key < $1.key }) {
                try write(text, to: relative.isEmpty ? move.to : move.to.appending(path: relative))
            }
            lines.append(
                "Moved \(Paths.display(move.from)) to \(Paths.display(move.to))"
                    + (move.changed == 0
                        ? "" : ", pointing \(count(move.changed)) in it at the new places"))
        }
        for rewrite in plan.rewrites {
            try write(rewrite.text, to: rewrite.file)
            lines.append(
                "Pointed \(count(rewrite.changed)) in \(Paths.display(rewrite.file)) at the new "
                    + "places")
        }
    }

    static let barArchiveNote = "# Cleaning up old configuration archived ~/.config/sketchybar in "

    static let barRestoreNote = "# Put it back with: macarchy cleanup --restore "

    /// Says in each kept own bar where the folder it relied on went, in place
    /// of what an earlier cleanup said; with no archive, only removes that.
    @discardableResult
    static func noteBarArchive(_ archive: URL?) throws -> [String] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: Paths.configDirectory.path)) ?? []
        var lines: [String] = []
        for name in names.sorted()
        where name.hasPrefix("own-bar-before-widgets") && name.hasSuffix(".sh") {
            let url = Paths.configDirectory.appending(path: name)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var kept = text.components(separatedBy: "\n").filter {
                !$0.hasPrefix(barArchiveNote) && !$0.hasPrefix(barRestoreNote)
            }
            if let archive {
                let header = kept.firstIndex { !$0.hasPrefix("#") } ?? kept.count
                kept.insert(
                    contentsOf: [
                        barArchiveNote + Paths.display(archive) + ".",
                        barRestoreNote + archive.lastPathComponent
                    ], at: header)
            }
            let updated = kept.joined(separator: "\n")
            guard updated != text else { continue }
            try write(updated, to: url)
            if archive != nil { lines.append("Noted the archive in \(Paths.display(url))") }
        }
        return lines
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
