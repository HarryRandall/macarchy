import Foundation

public enum Daemon: String, CaseIterable, Identifiable, Sendable {
    case yabai, borders, sketchybar, skhd

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .yabai: "yabai"
        case .borders: "borders"
        case .sketchybar: "SketchyBar"
        case .skhd: "skhd"
        }
    }

    public var role: String {
        switch self {
        case .yabai: "Tiling window manager"
        case .borders: "Window borders"
        case .sketchybar: "Menu bar"
        case .skhd: "Hotkey daemon"
        }
    }

    /// launchd job labels, read off the plists in ~/Library/LaunchAgents.
    public var launchdLabel: String {
        switch self {
        case .yabai: "com.asmvik.yabai"
        case .borders: "homebrew.mxcl.borders"
        case .sketchybar: "homebrew.mxcl.sketchybar"
        case .skhd: "com.koekeishiya.skhd"
        }
    }

    public var executable: String {
        switch self {
        case .yabai: Paths.yabai
        case .borders: Paths.borders
        case .sketchybar: Paths.sketchybar
        case .skhd: Paths.skhd
        }
    }
}

public enum DaemonState: Equatable, Sendable {
    case running(pid: Int)
    case stopped
    case unknown

    public var isRunning: Bool { if case .running = self { true } else { false } }

    public var label: String {
        switch self {
        case .running(let pid): "running · \(pid)"
        case .stopped: "stopped"
        case .unknown: "unknown"
        }
    }
}
