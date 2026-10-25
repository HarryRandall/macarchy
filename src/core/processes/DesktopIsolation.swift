import Foundation

/// Keeps isolated runs and tests off the real desktop.
///
/// `MACARCHY_HOME` and `MACARCHY_SEARCH_PATH` move Macarchy's files and the
/// daemons it finds, but launchd, the appearance setting, global defaults,
/// running apps and the real menu bar belong to the login session wherever
/// the home points. Every process starts in `CommandRunner`, which asks here
/// first. In an isolated run, or a test process even without either
/// variable, session tools and daemons only run as fakes under the home or
/// the search path. A refused command succeeds with the reason in
/// `skipped`, so an isolated setup or theme still runs to the end.
///
/// The installed app, the CLI under launchd and skhd's hotkeys set neither
/// variable and are not test processes, so none of this applies to them.
public enum DesktopIsolation {
    /// Whether this process must leave the real desktop alone.
    public static var isActive: Bool { Paths.isolated || isTestProcess }

    /// swift test and Xcode run tests in one of these helpers. Only the
    /// process name and Xcode's own variable are read, so no argument the
    /// CLI is given can make it count as a test.
    static let isTestProcess: Bool = {
        let info = ProcessInfo.processInfo
        return ["xctest", "swiftpm-testing-helper"].contains(info.processName)
            || info.environment["XCTestConfigurationFilePath"] != nil
    }()

    /// Tools that act on the login session whatever the home is.
    static let sessionTools: Set<String> = [
        // swiftlint:disable:next no_process_name_kill - names to refuse, never a process to signal.
        "launchctl", "defaults", "osascript", "pkill", "killall", "open", "sudo"
    ]

    /// Daemons and helpers that drive the real desktop.
    static let managedTools: Set<String> = [
        "yabai", "skhd", "sketchybar", "borders", "brew", "ghostty"
    ]

    /// Why `executable` may not run in this process, or nil when it may.
    static func refusal(_ executable: String, _ arguments: [String]) -> String? {
        guard isActive else { return nil }
        let environment = ProcessInfo.processInfo.environment
        let allowed =
            [environment["MACARCHY_HOME"]].compactMap { $0 }
            + (environment["MACARCHY_SEARCH_PATH"] ?? "").split(separator: ":").map(String.init)
        let personal =
            [Paths.scriptsDirectory.path]
            + ["yabai", "skhd", "borders", "sketchybar"].map {
                Paths.home.appending(path: ".config/\($0)").path
            }
        return refusal(
            executable, arguments, allowedRoots: allowed, personalScripts: personal)
    }

    /// The rule itself, with its inputs passed in so it can be tested
    /// without changing the process environment.
    ///
    /// The person's own scripts, in `personalScripts`, may only have their
    /// syntax checked: they often name Homebrew's daemons in full, so
    /// running one would drive the real desktop whatever the home is.
    static func refusal(
        _ executable: String, _ arguments: [String], allowedRoots: [String],
        personalScripts: [String] = []
    )
        -> String?
    {
        let name = URL(fileURLWithPath: executable).lastPathComponent
        let shells: Set<String> = ["bash", "sh", "zsh"]
        let script = shells.contains(name) ? arguments.first { !$0.hasPrefix("-") } : executable
        if arguments.first != "-n", let script, inside(script, roots: personalScripts) {
            return "\(URL(fileURLWithPath: script).lastPathComponent) was not run: a script of "
                + "your own is only checked in a run isolated from the desktop"
        }
        guard sessionTools.contains(name) || managedTools.contains(name) else { return nil }
        return inside(executable, roots: allowedRoots)
            ? nil : "\(name) was not run: this run is isolated from the desktop"
    }

    /// Whether `path`, as given or with links resolved, is below one of
    /// `roots`. An empty root or the file system root counts as none, so a
    /// stray value cannot allow everything.
    static func inside(_ path: String, roots: [String]) -> Bool {
        func spellings(_ path: String) -> [String] {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            return [url.path, url.resolvingSymlinksInPath().path]
        }
        let candidates = spellings(path)
        return roots.contains { root in
            guard !root.isEmpty else { return false }
            return spellings(root).contains { folder in
                guard folder != "/" else { return false }
                let prefix = folder.hasSuffix("/") ? folder : folder + "/"
                return candidates.contains { $0.hasPrefix(prefix) }
            }
        }
    }
}
