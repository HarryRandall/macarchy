import Foundation

/// Checks for the move from `~/.config/macarchy` to Application Support.
extension Doctor {
    /// The old folder still holds settings the new one lacks, so the move
    /// failed; everything else would describe defaults.
    static func unmovedCheck() -> HealthCheck? {
        guard LegacyLayout.needsMigration else { return nil }
        return HealthCheck(
            .configuration, "Setup", .failed,
            "Settings from an earlier version are still in "
                + "\(Paths.display(LegacyLayout.linkedFolder ?? Paths.legacyRoot)) and were not "
                + "moved",
            fix: "Quit Macarchy and run setup; it says what stopped the move",
            command: setupCommand)
    }

    /// The file SketchyBar's agent names, when it is gone, as happens when
    /// the person's bar folder holding the launcher is deleted.
    static func missingBarStartFile() -> URL? {
        guard
            let arguments = DaemonAgents.definition(at: DaemonAgents.plist(.sketchybar))?.arguments,
            let index = arguments.firstIndex(of: "--config"), index + 1 < arguments.count
        else { return nil }
        let file = URL(fileURLWithPath: arguments[index + 1])
        return FileManager.default.fileExists(atPath: file.path) ? nil : file
    }

    /// Setup has not run since the move, and data Macarchy no longer reads:
    /// an earlier version's folder kept beside the new one, or files a merge
    /// set aside because they clashed.
    static func layoutChecks() -> [HealthCheck] {
        var results: [HealthCheck] = []
        if LegacyLayout.awaitingSetup {
            results.append(
                HealthCheck(
                    .configuration, "Setup", .failed,
                    "Set up before Macarchy moved to Application Support",
                    fix: "Open Macarchy to set it up again", command: setupCommand))
        }
        if let note = LegacyLayout.note {
            results.append(
                HealthCheck(
                    .configuration, "Earlier folder", .passed,
                    note.lines.joined(separator: ". ")))
        }
        if LegacyLayout.hasLeftoverData { results.append(leftoverCheck()) }
        if let missing = missingBarStartFile() {
            results.append(
                HealthCheck(
                    .configuration, "SketchyBar agent", .failed,
                    "Macarchy's agent starts \(Paths.display(missing)), which is missing",
                    fix: "Run setup again", command: setupCommand))
        }
        for folder in LegacyLayout.setAsideFolders {
            results.append(
                HealthCheck(
                    .configuration, "Set-aside files", .warning,
                    "\(Paths.display(folder)) holds files that clashed when settings moved",
                    fix: "Copy anything you need into \(Paths.display(Paths.appRoot)), "
                        + "then move the folder to the Bin",
                    file: folder))
        }
        return results
    }

    /// The old folder still holds settings Macarchy no longer reads, or a
    /// link the person made leads to a folder that does.
    private static func leftoverCheck() -> HealthCheck {
        guard let target = LegacyLayout.linkedFolder else {
            return HealthCheck(
                .configuration, "Earlier settings", .warning,
                "\(Paths.display(Paths.legacyRoot)) still holds settings from an earlier "
                    + "version, which Macarchy no longer reads",
                fix: "Copy anything you need into \(Paths.display(Paths.appRoot)), "
                    + "then move the old folder to the Bin",
                file: Paths.legacyRoot)
        }
        return HealthCheck(
            .configuration, "Earlier settings", .warning,
            "\(Paths.display(Paths.legacyRoot)) links to \(Paths.display(target)), which still "
                + "holds settings from an earlier version. Macarchy copied them to "
                + "\(Paths.display(Paths.appRoot)) and no longer reads that folder",
            fix: "Keep your settings in \(Paths.display(Paths.appRoot)) from now on. Remove the "
                + "link, or the earlier settings from that folder, when nothing names it",
            file: target)
    }
}
