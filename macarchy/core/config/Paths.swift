import Foundation

/// Every filesystem location the app and CLI depend on, in one place.
///
/// Macarchy owns exactly one folder, `~/.config/macarchy`. The only files it
/// writes outside it are the startup files the daemons read from fixed places,
/// and Ghostty's include line, all of which setup backs up first.
public enum Paths {
    public static var home: URL {
        URL(
            fileURLWithPath: ProcessInfo.processInfo.environment["MACARCHY_HOME"]
                ?? NSHomeDirectory())
    }

    public static var appRoot: URL { home.appending(path: ".config/macarchy") }
    public static var settings: URL { appRoot.appending(path: "settings.json") }
    public static var themesDirectory: URL { appRoot.appending(path: "themes") }
    public static var snapshotsDirectory: URL { appRoot.appending(path: "snapshots") }
    /// Files rendered from the active theme for other programs to read.
    public static var generatedDirectory: URL { appRoot.appending(path: "generated") }
    /// Originals of every file setup replaced, kept until uninstall.
    public static var backupsDirectory: URL { appRoot.appending(path: "backups") }
    /// Drop-in replacements for daemon executables, such as a custom borders build.
    public static var binDirectory: URL { appRoot.appending(path: "bin") }

    /// A link to the installed app, so startup files and bar plugins have one
    /// stable path to the bundled CLI and resources wherever the app lives.
    public static var appLink: URL { appRoot.appending(path: "Macarchy.app") }

    /// The command startup files run. Spelled with `$HOME` so the file stays
    /// correct if the account is renamed or restored onto another Mac.
    public static let cliInShell = "\"$HOME/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy\""

    // MARK: - Bundled resources

    /// Themes, the starter bar and default shortcuts shipped with the app.
    ///
    /// `MACARCHY_RESOURCES` points development builds and tests at the
    /// repository; installed copies read the app bundle, through the link if
    /// the caller is the CLI started by launchd.
    public static var resources: URL? {
        let fm = FileManager.default
        func valid(_ url: URL) -> Bool {
            fm.fileExists(atPath: url.appending(path: "themes").path)
        }
        if let override = ProcessInfo.processInfo.environment["MACARCHY_RESOURCES"] {
            return URL(fileURLWithPath: override)
        }
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.executableURL?.resolvingSymlinksInPath()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "Resources"),
            appLink.appending(path: "Contents/Resources")
        ]
        return candidates.compactMap { $0 }.first(where: valid)
    }

    // MARK: - Executables

    public static var yabai: String { executable("yabai") }
    public static var skhd: String { executable("skhd") }
    public static var sketchybar: String { executable("sketchybar") }
    public static var borders: String { executable("borders") }
    public static var ghostty: String { executable("ghostty") }
    public static let launchctl = "/bin/launchctl"
    public static let defaults = "/usr/bin/defaults"
    public static let ioreg = "/usr/sbin/ioreg"
    public static let ps = "/bin/ps"
    public static let tail = "/usr/bin/tail"

    /// Homebrew prefixes for Apple Silicon and Intel, in that order.
    /// `MACARCHY_SEARCH_PATH` replaces them, so tests can supply fakes and
    /// never reach the real daemons.
    static var searchDirectories: [String] {
        if let override = ProcessInfo.processInfo.environment["MACARCHY_SEARCH_PATH"] {
            return override.split(separator: ":").map(String.init)
        }
        return ["/opt/homebrew/bin", "/usr/local/bin"]
    }

    /// Finds a daemon executable without relying on the caller's PATH, which
    /// is minimal under launchd and in apps opened from Finder.
    ///
    /// A file in `~/.config/macarchy/bin` wins, so a custom build can replace
    /// the Homebrew one without editing anything else. When nothing is found
    /// the Apple Silicon path is returned and checks report it as missing.
    public static func executable(_ name: String) -> String {
        let fm = FileManager.default
        let directories = [binDirectory.path] + searchDirectories
        for directory in directories {
            let candidate = directory + "/" + name
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        let environment = ProcessInfo.processInfo.environment
        let path = environment["MACARCHY_SEARCH_PATH"] == nil ? environment["PATH"] ?? "" : ""
        for directory in path.split(separator: ":") {
            let candidate = String(directory) + "/" + name
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return searchDirectories[0] + "/" + name
    }

    /// Where apps are installed. `MACARCHY_APPLICATIONS` replaces the list in tests.
    public static var applicationDirectories: [URL] {
        if let override = ProcessInfo.processInfo.environment["MACARCHY_APPLICATIONS"] {
            return override.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        }
        return [URL(fileURLWithPath: "/Applications"), home.appending(path: "Applications")]
    }

    public static func hasApplication(_ name: String) -> Bool {
        applicationDirectories.contains {
            FileManager.default.fileExists(atPath: $0.appending(path: name + ".app").path)
        }
    }

    public static func isInstalled(_ name: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: executable(name))
    }

    /// Home-relative spelling for display, so screenshots do not show the username.
    public static func display(_ url: URL) -> String {
        let homePath = home.path
        let path = url.path
        return path.hasPrefix(homePath + "/") ? "~" + path.dropFirst(homePath.count) : path
    }
}
