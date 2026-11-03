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
                    report.failure = failure(error, report: report)
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

    /// Why cleaning up stopped, saying when nothing had changed yet. Writing
    /// the archive is the first step, and it changes none of the person's files.
    static func failure(_ error: Error, report: Report) -> String {
        let message = error.localizedDescription
        let changes = report.lines.dropFirst(report.archive == nil ? 0 : 1)
        guard !changes.isEmpty else {
            return message.contains("Nothing was changed")
                || message.contains("nothing was changed")
                ? message : message + " Nothing was changed."
        }
        return "Cleaning up stopped part way: \(message)"
            + (report.archive.map {
                " Everything it changed is in \(Paths.display($0)); put it back "
                    + "with macarchy cleanup --restore \($0.lastPathComponent)."
            } ?? "")
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
        let saved = try await archive(plan, into: &report)
        let changed = plan.rewrites.map(\.file).filter { fm.fileExists(atPath: $0.path) }
        if !changed.isEmpty {
            try SnapshotStore().capture(changed, reason: "before cleaning up old configuration")
        }

        try moveAndPoint(plan, into: &report.lines)

        if plan.replacedLink != nil {
            try fm.removeItem(at: Paths.launcherDirectory)
            report.lines.append(
                "Removed the old configuration link; launchers are bundled in the app")
        }
        try relocateAndDelete(plan, archived: saved.archived, into: &report.lines)
        let bar = OldConfiguration.folder("sketchybar")
        if plan.removals.contains(where: { $0.path.path == bar.path }) {
            report.lines += try noteBarArchive(saved.url)
        }
        report.lines += plan.kept.map { "Left \(Paths.display($0.path)): \($0.reason)" }
        return plan.restarts
    }

    /// Writes the archive, says what it left out, and stops the helpers
    /// still running from a folder that goes.
    static func archive(_ plan: Plan, into report: inout Report) async throws -> Written {
        let saved = try await writeArchive(try manifest(for: plan))
        report.archive = saved.url
        report.lines.append(
            "Archived everything below in \(Paths.display(saved.url)). Put it back with: "
                + "macarchy cleanup --restore \(saved.url.lastPathComponent)")
        report.lines += saved.manifest.entries.filter { $0.action == .skipped }.map {
            let url = Paths.home.appending(path: $0.path)
            return
                "Did not archive \(Paths.display(url)), a \(describeSpecial(url)) only a running "
                + "program uses; it is deleted with its folder"
        }
        report.lines += stopHelpers(in: plan.removals.map(\.path).filter(isFolder))
        return saved
    }

    /// Moves the launchers into the launcher folder, then deletes what the
    /// archive holds of everything that goes. Anything that appeared since
    /// archiving stays and is reported.
    static func relocateAndDelete(
        _ plan: Plan, archived: [String: Fingerprint], into lines: inout [String]
    ) throws {
        var left: [URL] = []
        func delete(_ url: URL) throws -> Bool {
            guard let key = homeRelative(url) else { return false }
            return try deleteArchived(url, key: key, archived: archived, left: &left)
        }
        let backups = Backups()
        for moved in plan.launchers {
            guard let launcher = StartLauncher.all.first(where: { $0.daemon == moved.daemon })
            else { continue }
            lines += try launcher.place(at: launcher.newURL, backups: backups)
            if try delete(moved.from) { lines.append("Deleted \(Paths.display(moved.from))") }
            if DaemonAgents.isInstalled(moved.daemon) {
                try DaemonAgents.install(moved.daemon, backups: backups, report: &lines)
            }
        }
        for move in plan.moves where exists(move.from) { _ = try delete(move.from) }
        for item in plan.removals where exists(item.path) {
            if try delete(item.path) { lines.append("Deleted \(Paths.display(item.path))") }
        }
        lines += left.map {
            "Left \(Paths.display($0)), which appeared after archiving, so it is not in the archive"
        }
    }

    /// Moves the scripts, then points every file that names them at their new place.
    static func moveAndPoint(_ plan: Plan, into lines: inout [String]) throws {
        let fm = FileManager.default
        for move in plan.moves {
            try fm.createDirectory(at: Paths.scriptsDirectory, withIntermediateDirectories: true)
            var copied = Copied()
            try copyTree(move.from, to: move.to, key: move.from.path, into: &copied)
            lines += copied.skipped.map {
                "Did not move \(Paths.display(URL(fileURLWithPath: $0))), a "
                    + "\(describeSpecial(URL(fileURLWithPath: $0))) only a running program uses"
            }
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
