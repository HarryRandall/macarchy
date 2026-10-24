import Foundation

/// Every filesystem location the app and CLI depend on, in one place.
///
/// Macarchy owns exactly one folder, `~/.config/macarchy`. The only files it
/// writes outside it are the startup files the daemons read from fixed places,
/// and Ghostty's include line, all of which setup backs up first.
public enum Paths {
    public static var home: URL { home(in: ProcessInfo.processInfo.environment) }

    static func home(in environment: [String: String]) -> URL {
        URL(fileURLWithPath: environment["MACARCHY_HOME"] ?? NSHomeDirectory())
    }

    /// A development run or test, which must never reach the real login
    /// session, global defaults, sudoers or LaunchAgents. Either variable is
    /// enough, so a run that sets only one is still kept away from them. Read
    /// on every use, because the web view tests set both after launch. A
    /// `MACARCHY_HOME` that is the account's own home relocates nothing, so on
    /// its own it does not count. See also `DesktopIsolation`.
    public static var isolated: Bool { isolated(in: ProcessInfo.processInfo.environment) }

    static func isolated(in environment: [String: String], homes: [String] = realHomes) -> Bool {
        environment["MACARCHY_SEARCH_PATH"] != nil || relocatesHome(in: environment, homes: homes)
    }

    /// Whether `MACARCHY_HOME` names a home other than the account's own,
    /// compared with links resolved.
    static func relocatesHome(
        in environment: [String: String], homes: [String] = realHomes
    )
        -> Bool
    {
        guard let home = environment["MACARCHY_HOME"] else { return false }
        func resolved(_ path: String) -> String {
            URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        }
        let target = resolved(home)
        return !homes.contains { resolved($0) == target }
    }

    /// The account's home from the user database. `NSHomeDirectory` ignores
    /// `HOME` on macOS, but both are checked in case either is redirected.
    static let realHomes: [String] = {
        var homes = [NSHomeDirectory()]
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            homes.append(String(cString: directory))
        }
        return homes
    }()

    public static var appRoot: URL { home.appending(path: ".config/macarchy") }
    public static var settings: URL { appRoot.appending(path: "settings.json") }
    public static var themesDirectory: URL { appRoot.appending(path: "themes") }
    /// Bar widgets people made or imported, one folder each.
    public static var widgetsDirectory: URL { appRoot.appending(path: "widgets") }
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

    // MARK: - Fixed locations

    /// The shortcuts file skhd reads: `~/.config/skhd/skhdrc`, or an older
    /// `~/.skhdrc` when only that exists. skhd is started by its own
    /// LaunchAgent without `-c`, so this is its search order. Setup, the
    /// Shortcuts page and Home all use it, so a dotfile is edited in place
    /// rather than shadowed or replaced.
    public static var skhdrc: URL { skhdrc(home: home) }

    static func skhdrc(home: URL) -> URL {
        let primary = home.appending(path: ".config/skhd/skhdrc")
        let dotfile = home.appending(path: ".skhdrc")
        let fm = FileManager.default
        return !fm.fileExists(atPath: primary.path) && fm.fileExists(atPath: dotfile.path)
            ? dotfile : primary
    }

    // MARK: - Bundled resources

    /// Themes, the starter bar and default shortcuts shipped with the app.
    ///
    /// `MACARCHY_RESOURCES` points development builds and tests at a folder
    /// in the bundle's layout; installed copies read the app bundle, through
    /// the link if the caller is the CLI started by launchd.
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
    public static var launchctl: String { launchctl(in: ProcessInfo.processInfo.environment) }
    public static var defaults: String { defaults(in: ProcessInfo.processInfo.environment) }
    public static let ioreg = "/usr/sbin/ioreg"
    public static let ps = "/bin/ps"
    public static let tail = "/usr/bin/tail"

    /// Homebrew prefixes for Apple Silicon and Intel, in that order.
    /// `MACARCHY_SEARCH_PATH` replaces them, so tests can supply fakes and
    /// never reach the real daemons. An empty value is still an override,
    /// with no directories at all. An isolated home without it searches
    /// nowhere, so every daemon reads as missing rather than the real one.
    static var searchDirectories: [String] {
        searchDirectories(in: ProcessInfo.processInfo.environment)
    }

    static func searchDirectories(in environment: [String: String]) -> [String] {
        if let override = environment["MACARCHY_SEARCH_PATH"] {
            return override.split(separator: ":").map(String.init)
        }
        return isolated(in: environment) ? [] : ["/opt/homebrew/bin", "/usr/local/bin"]
    }

    /// Finds a daemon executable without relying on the caller's PATH, which
    /// is minimal under launchd and in apps opened from Finder.
    ///
    /// A file in `~/.config/macarchy/bin` wins, so a custom build can replace
    /// the Homebrew one without editing anything else. When nothing is found
    /// the first searched path is returned and checks report it as missing.
    public static func executable(_ name: String) -> String {
        executable(name, in: ProcessInfo.processInfo.environment)
    }

    static func executable(_ name: String, in environment: [String: String]) -> String {
        let fm = FileManager.default
        let bin = home(in: environment).appending(path: ".config/macarchy/bin").path
        let searched = searchDirectories(in: environment)
        for directory in [bin] + searched {
            let candidate = directory + "/" + name
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        let path = isolated(in: environment) ? "" : environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = String(directory) + "/" + name
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return missing(name, searched: searched, environment: environment)
    }

    static func launchctl(in environment: [String: String]) -> String {
        systemTool("launchctl", at: "/bin/launchctl", in: environment)
    }

    static func defaults(in environment: [String: String]) -> String {
        systemTool("defaults", at: "/usr/bin/defaults", in: environment)
    }

    /// launchctl and defaults act on the login session and the global domain
    /// whatever `MACARCHY_HOME` says, so an isolated run only uses a fake on
    /// `MACARCHY_SEARCH_PATH`. Without one the path names a file that does
    /// not exist, so the command fails instead of reaching the real tool.
    private static func systemTool(
        _ name: String, at system: String, in environment: [String: String]
    ) -> String {
        guard isolated(in: environment) else { return system }
        let directories =
            environment["MACARCHY_SEARCH_PATH"]?.split(separator: ":").map(String.init) ?? []
        for directory in directories {
            let candidate = directory + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return missing(name, searched: directories, environment: environment)
    }

    /// Where a tool that was not found is reported to be. The first searched
    /// folder was already checked; with none, a folder inside the app's own
    /// bin that nothing creates, so the path cannot name a real file.
    private static func missing(
        _ name: String, searched: [String], environment: [String: String]
    ) -> String {
        if let first = searched.first { return first + "/" + name }
        return home(in: environment).appending(path: ".config/macarchy/bin/.missing/\(name)").path
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
