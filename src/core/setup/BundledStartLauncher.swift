import Foundation

/// Daemons run their config path through an unquoted shell command. Bundled
/// launchers keep that path free of spaces without creating XDG configuration.
enum BundledStartLauncher {
    static func url(_ daemon: Daemon) -> URL {
        let resources = Paths.resources ?? Paths.appLink.appending(path: "Contents/Resources")
        return resources.appending(path: "launchers/macarchy-\(daemon.rawValue)rc")
            .resolvingSymlinksInPath()
    }

    /// Checks the launchers of the chosen `tools` that are installed.
    static func validate(_ tools: Set<Daemon> = Setup.chosenTools) throws {
        for daemon in [Daemon.yabai, .sketchybar]
        where tools.contains(daemon) && Paths.isInstalled(daemon.executableName) {
            let file = url(daemon)
            // The agents name this file where it is now, so a copy that is
            // about to move or vanish would leave them pointing at nothing.
            let path = file.path
            guard !path.contains("/AppTranslocation/"), !path.hasPrefix("/Volumes/"),
                !path.contains("/.build/")
            else {
                throw ConfigurationError(
                    "Move Macarchy.app to /Applications and open it from there before setup. "
                        + "Its launchers are used from where the app is: \(path).")
            }
            guard path.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
                throw ConfigurationError(
                    "Install Macarchy.app in /Applications before setup. Its launcher path "
                        + "cannot contain spaces: \(file.path).")
            }
            guard FileManager.default.isExecutableFile(atPath: file.path) else {
                throw ConfigurationError(
                    "Macarchy's bundled \(daemon.displayName) launcher is missing. Rebuild "
                        + "and install the app before setup.")
            }
        }
    }
}
