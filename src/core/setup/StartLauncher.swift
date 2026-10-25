import Foundation

/// The small file yabai's or SketchyBar's agent starts, which hands over to
/// that tool's startup file in `Paths.configDirectory`.
///
/// Both tools run the file they are started with as `sh -c <path>`, with the
/// path unquoted, so sh splits it at the space in "Application Support" and
/// the startup file never runs: no layout, rules, signals or bar. A launcher
/// in the tool's own folder, `~/.config/<tool>`, has no space in its path,
/// and its one command quotes the real one. A link would not do: SketchyBar
/// resolves links before it runs the file.
///
/// SketchyBar also sets `$CONFIG_DIR`, and its working folder, to the folder
/// of the file it starts with and passes both to every item script. A
/// person's own bar finds its plugins, colours and icons through them, so its
/// launcher belongs in that folder anyway. Macarchy's bar names its scripts
/// in full and does not mind.
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

    public var url: URL {
        Paths.home.appending(path: ".config/\(daemon.rawValue)/macarchy-\(daemon.rawValue)rc")
    }

    /// Identifies the file as Macarchy's, so setup may replace it and
    /// uninstall remove it. SketchyBar's matches what earlier versions wrote.
    var marker: String { "# Written by Macarchy for its \(daemon.displayName) agent." }

    var content: String {
        let home = Paths.home.path
        let path = target.path
        let spelled = path.hasPrefix(home + "/") ? "$HOME" + path.dropFirst(home.count) : path
        let why =
            daemon == .sketchybar
            ? """
            # SketchyBar runs the file it starts with through sh, which splits a path
            # with a space, and gives your items this folder as $CONFIG_DIR, as it did
            # before Macarchy. The bar itself, with your own region:
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
    public var isMacarchys: Bool {
        (try? String(contentsOf: url, encoding: .utf8))?.contains(marker) == true
    }

    /// Whether setup still has to write it.
    var isCurrent: Bool { (try? String(contentsOf: url, encoding: .utf8)) == content }

    /// The plan's line for the launcher, when setup will write it.
    var change: Setup.Change? {
        guard !isCurrent else { return nil }
        let exists = FileManager.default.fileExists(atPath: url.path)
        let reason =
            daemon == .sketchybar
            ? "SketchyBar cannot start a file in Application Support, whose name has a space, "
                + "and your bar's items find their files in this folder"
            : "yabai cannot start a file in Application Support, whose name has a space"
        return Setup.Change(
            path: url, action: exists ? .replace : .create,
            detail: "Starts \(daemon.displayName) here and hands over to "
                + "\(Paths.display(target)). \(reason). Uninstall removes it")
    }

    /// Writes the launcher, backed up as absent first so uninstall removes
    /// it. A file of the same name that is not Macarchy's stops setup.
    func place(backups: Backups) throws -> [String] {
        guard !isCurrent else { return [] }
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path), !isMacarchys {
            throw ConfigurationError(
                "\(Paths.display(url)) exists and is not Macarchy's. Move it aside, then "
                    + "set up again.")
        }
        var lines = try backups.save([url]).map { "Backed up \(Paths.display($0))" }
        try fm.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        lines.append("Wrote \(Paths.display(url)), so \(daemon.displayName) runs its startup file")
        return lines
    }
}
