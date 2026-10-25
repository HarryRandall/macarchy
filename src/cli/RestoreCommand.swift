import Foundation
import Macarchy

/// `macarchy restore <snapshot> [--apply]`: puts back the files in a
/// snapshot, and with `--apply` reapplies them.
func restore(_ options: CommandArguments) async throws {
    let store = SnapshotStore()
    guard let snapshot = store.list().first(where: { $0.id == options.values[0] }) else {
        throw ConfigurationError(
            "Snapshot \(options.values[0]) not found. Snapshots are listed in Advanced.")
    }
    func restoredLine(_ files: [URL]) -> String {
        "Restored " + files.map { Paths.display($0) }.joined(separator: ", ") + "."
    }
    if options.flags.contains("--apply") {
        let files = try await DesktopConfiguration.restore(snapshot, store: store)
        print(restoredLine(files) + " Applied snapshot \(snapshot.id).")
    } else {
        let files = try await store.restoreLocked(snapshot)
        print(
            restoredLine(files) + " Update the desktop with: macarchy restore \(snapshot.id)"
                + " --apply, or macarchy apply if your shortcuts are unchanged.")
    }
}
