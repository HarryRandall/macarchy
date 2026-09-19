import Foundation

enum Daemon: String, CaseIterable, Identifiable, Sendable {
    case yabai, borders, sketchybar, skhd

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yabai: "yabai"
        case .borders: "borders"
        case .sketchybar: "SketchyBar"
        case .skhd: "skhd"
        }
    }

    var role: String {
        switch self {
        case .yabai: "Tiling window manager"
        case .borders: "Window borders"
        case .sketchybar: "Menu bar"
        case .skhd: "Hotkey daemon"
        }
    }

    /// launchd job labels, read off the plists in ~/Library/LaunchAgents.
    var launchdLabel: String {
        switch self {
        case .yabai: "com.asmvik.yabai"
        case .borders: "homebrew.mxcl.borders"
        case .sketchybar: "homebrew.mxcl.sketchybar"
        case .skhd: "com.koekeishiya.skhd"
        }
    }

    var executable: String {
        switch self {
        case .yabai: Paths.yabai
        case .borders: Paths.borders
        case .sketchybar: Paths.sketchybar
        case .skhd: Paths.skhd
        }
    }
}

enum DaemonState: Equatable, Sendable {
    case running(pid: Int)
    case stopped
    case unknown

    var isRunning: Bool { if case .running = self { true } else { false } }

    var label: String {
        switch self {
        case .running(let pid): "running · \(pid)"
        case .stopped: "stopped"
        case .unknown: "unknown"
        }
    }
}

enum Paths {
    static let yabai = "/opt/homebrew/bin/yabai"
    static let borders = "/opt/homebrew/bin/borders"
    static let sketchybar = "/opt/homebrew/bin/sketchybar"
    static let skhd = "/opt/homebrew/bin/skhd"
    static let launchctl = "/bin/launchctl"

    static var home: URL { URL(fileURLWithPath: NSHomeDirectory()) }
    static var themeSwitch: String { home.appending(path: ".local/bin/theme-switch").path }

    /// Everything this app owns lives here. The old ~/.config/macarchy and
    /// ~/.local/state/macarchy trees are retired; ~/.config/themes remains as a
    /// symlink so the shell scripts that still hard-code it keep resolving.
    static var appRoot: URL { home.appending(path: ".config/macarchy-settings") }

    static var themesDirectory: URL { appRoot.appending(path: "themes") }
    static var snapshotsDirectory: URL { appRoot.appending(path: "snapshots") }

    /// Written by this app, sourced by the rc scripts. Never contains shell logic.
    static var settingsEnv: URL { appRoot.appending(path: "settings.env") }
}
