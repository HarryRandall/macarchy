import Foundation

/// Every filesystem location the app and CLI depend on, in one place.
public enum Paths {
    public static let yabai = "/opt/homebrew/bin/yabai"
    public static var borders: String {
        let local = home.appending(path: ".local/bin/macarchy-borders").path
        return FileManager.default.isExecutableFile(atPath: local)
            ? local : "/opt/homebrew/bin/borders"
    }
    public static let sketchybar = "/opt/homebrew/bin/sketchybar"
    public static let skhd = "/opt/homebrew/bin/skhd"
    public static let launchctl = "/bin/launchctl"
    public static let defaults = "/usr/bin/defaults"
    public static let ioreg = "/usr/sbin/ioreg"
    public static let ps = "/bin/ps"
    public static let tail = "/usr/bin/tail"

    public static var home: URL {
        URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["MACARCHY_HOME"]
                ?? NSHomeDirectory())
    }

    /// Everything this app owns lives here. The old ~/.config/macarchy and
    /// ~/.local/state/macarchy trees are retired; ~/.config/themes remains as a
    /// symlink so the shell scripts that still hard-code it keep resolving.
    public static var appRoot: URL { home.appending(path: ".config/macarchy-settings") }

    public static var themesDirectory: URL { appRoot.appending(path: "themes") }
    public static var snapshotsDirectory: URL { appRoot.appending(path: "snapshots") }

}
