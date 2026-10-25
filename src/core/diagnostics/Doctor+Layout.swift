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
                + "\(Paths.display(Paths.legacyRoot)) and were not moved",
            fix: "Quit Macarchy and run setup; it says what stopped the move",
            command: setupCommand)
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
        if LegacyLayout.hasLeftoverData {
            results.append(
                HealthCheck(
                    .configuration, "Earlier settings", .warning,
                    "\(Paths.display(Paths.legacyRoot)) still holds settings from an earlier "
                        + "version, which Macarchy no longer reads",
                    fix: "Copy anything you need into \(Paths.display(Paths.appRoot)), "
                        + "then move the old folder to the Bin",
                    file: Paths.legacyRoot))
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
}
