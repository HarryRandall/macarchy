import Darwin
import Foundation

/// The small file yabai's or SketchyBar's agent starts, which hands over to
/// that tool's startup file in `Paths.configDirectory`.
///
/// Both tools run the file they are started with as `sh -c <path>`, with the
/// path unquoted, so sh splits it at the space in "Application Support" and
/// the startup file never runs: no layout, rules, signals or bar. A launcher
/// in `Paths.launcherDirectory`, `~/.config/macarchy`, has no space in its
/// path, and its one command quotes the real one. A link would not do:
/// SketchyBar resolves links before it runs the file, which is also why that
/// folder is a real one and not a link into Application Support.
///
/// Earlier versions put each launcher in the tool's own folder,
/// `~/.config/<tool>`. A launcher stays there while it is there and the new
/// one is not, or while an upgrade's link still stands at the launcher
/// folder.
///
/// SketchyBar sets `$CONFIG_DIR` to the folder of the file it starts with;
/// Macarchy's bar names everything in full and does not mind where that is.
///
/// borders needs none: launchd runs bordersrc itself, with no shell between.
/// skhd only reads its file.
public struct StartLauncher: Sendable, Equatable {
    public let daemon: Daemon
    /// The startup file the launcher hands over to.
    let target: URL

    public static var yabai: StartLauncher {
        StartLauncher(daemon: .yabai, target: StartupConfiguration.yabairc.url)
    }

    public static var sketchybar: StartLauncher {
        StartLauncher(daemon: .sketchybar, target: StartupConfiguration.sketchybarrc.url)
    }

    public static var all: [StartLauncher] { [yabai, sketchybar] }

    /// Where the launcher is, or goes when setup writes it.
    public var url: URL { staysInToolFolder ? legacyURL : newURL }

    var fileName: String { "macarchy-\(daemon.rawValue)rc" }

    /// In Macarchy's launcher folder.
    var newURL: URL { Paths.launcherDirectory.appending(path: fileName) }

    /// In the tool's own folder, where earlier versions put it.
    var legacyURL: URL {
        Paths.home.appending(path: ".config/\(daemon.rawValue)/\(fileName)")
    }

    /// Whether the launcher belongs in the tool's own folder for now: the
    /// launcher folder is a link or a file, or an earlier version's launcher
    /// is in place and the new one is not.
    var staysInToolFolder: Bool {
        !Self.folderIsUsable
            || (Self.isMacarchys(at: legacyURL, daemon: daemon)
                && !FileManager.default.fileExists(atPath: newURL.path))
    }

    /// Whether launchers can go in `Paths.launcherDirectory`: nothing is
    /// there, or a real folder is.
    static var folderIsUsable: Bool {
        var info = stat()
        guard lstat(Paths.launcherDirectory.path, &info) == 0 else { return true }
        return info.st_mode & S_IFMT == S_IFDIR
    }

    /// Identifies the file as Macarchy's, so setup may replace it and
    /// uninstall remove it. SketchyBar's matches what earlier versions wrote.
    var marker: String { Self.marker(daemon) }

    static func marker(_ daemon: Daemon) -> String {
        "# Written by Macarchy for its \(daemon.displayName) agent."
    }

    /// The launcher, the same wherever it is.
    var content: String {
        let home = Paths.home.path
        let path = target.path
        let spelled = path.hasPrefix(home + "/") ? "$HOME" + path.dropFirst(home.count) : path
        let why =
            daemon == .sketchybar
            ? """
            # SketchyBar runs the file it starts with through sh, which splits a path
            # with a space, so it starts here. The bar and your own region:
            """
            : """
            # yabai runs the file it starts with through sh, which splits a path with
            # a space, so it starts here. Layout, rules and your own region:
            """
        return """
            #!/bin/bash
            \(marker)
            \(why)
            #   \(Paths.display(target))
            # Uninstalling Macarchy removes this file.
            exec "\(spelled)" "$@"

            """
    }

    /// Whether the launcher is in place and Macarchy's.
    public var isMacarchys: Bool { Self.isMacarchys(at: url, daemon: daemon) }

    static func isMacarchys(at url: URL, daemon: Daemon) -> Bool {
        (try? String(contentsOf: url, encoding: .utf8))?.contains(marker(daemon)) == true
    }

    /// Whether setup still has to write it.
    var isCurrent: Bool { (try? String(contentsOf: url, encoding: .utf8)) == content }

    /// The plan's line for the launcher, when setup will write it.
    var change: Setup.Change? {
        guard !isCurrent else { return nil }
        let exists = FileManager.default.fileExists(atPath: url.path)
        let reason =
            "\(daemon.displayName) cannot start a file in Application Support, whose name has a "
            + "space"
        return Setup.Change(
            path: url, action: exists ? .replace : .create,
            detail: "Starts \(daemon.displayName) here and hands over to "
                + "\(Paths.display(target)). \(reason). Uninstall removes it")
    }

    /// Writes the launcher, backed up as absent first so uninstall removes
    /// it. A file of the same name that is not Macarchy's stops setup.
    func place(backups: Backups) throws -> [String] {
        try place(at: url, backups: backups)
    }

    /// Writes the launcher at `destination`, which cleanup uses to move it
    /// into the launcher folder.
    func place(at destination: URL, backups: Backups) throws -> [String] {
        guard (try? String(contentsOf: destination, encoding: .utf8)) != content else { return [] }
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path),
            !Self.isMacarchys(at: destination, daemon: daemon)
        {
            throw ConfigurationError(
                "\(Paths.display(destination)) exists and is not Macarchy's. Move it aside, then "
                    + "set up again.")
        }
        var lines = try backups.save([destination]).map { "Backed up \(Paths.display($0))" }
        try fm.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: destination, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        lines.append(
            "Wrote \(Paths.display(destination)), so \(daemon.displayName) runs its startup file")
        return lines
    }
}
