import Foundation

/// Earlier versions kept everything in `~/.config/macarchy`. The first run of
/// this version moves that folder into Application Support whole, so settings,
/// themes and history carry over, and leaves a link in its place so startup
/// files written by the earlier version keep working until setup runs again.
public enum LegacyLayout {
    /// Moves the old folder if there is one and nothing is in the new place
    /// yet. Returns whether it moved anything.
    @discardableResult
    public static func migrate() -> Bool {
        let fm = FileManager.default
        guard isFolder(Paths.legacyRoot), !fm.fileExists(atPath: Paths.appRoot.path) else {
            return false
        }
        do {
            try fm.createDirectory(
                at: Paths.appRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: Paths.legacyRoot, to: Paths.appRoot)
            try fm.createSymbolicLink(
                atPath: Paths.legacyRoot.path, withDestinationPath: Paths.appRoot.path)
            return true
        } catch {
            return false
        }
    }

    /// Whether the old folder still stands in for the new one, as the link
    /// `migrate` leaves.
    public static var linkRemains: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: Paths.legacyRoot.path)) != nil
    }

    /// Removes the link once setup has written startup files in the new place.
    static func removeLink() throws {
        guard linkRemains else { return }
        try FileManager.default.removeItem(at: Paths.legacyRoot)
    }

    private static func isFolder(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
        let link = (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
        return exists && directory.boolValue && !link
    }
}
