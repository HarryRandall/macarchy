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

    /// Labels each installer is known to use, newest first. yabai and skhd
    /// moved from koekeishiya to asmvik, and Homebrew services moved from
    /// homebrew.mxcl to sh.brew; both spellings of each are still in the wild.
    public var knownLabels: [String] {
        switch self {
        case .yabai: ["com.asmvik.yabai", "com.koekeishiya.yabai"]
        case .borders: [BordersService.label, "sh.brew.borders", "homebrew.mxcl.borders"]
        case .sketchybar: ["sh.brew.sketchybar", "homebrew.mxcl.sketchybar"]
        case .skhd: ["com.asmvik.skhd", "com.koekeishiya.skhd"]
        }
    }

    /// The launchd job actually installed, read off ~/Library/LaunchAgents.
    /// Falls back to the newest known label so a missing job is reported
    /// under the name the current installer would create.
    public var launchdLabel: String {
        let agents = Paths.home.appending(path: "Library/LaunchAgents")
        return knownLabels.first {
            FileManager.default.fileExists(atPath: agents.appending(path: "\($0).plist").path)
        } ?? knownLabels[0]
    }

    /// Whether a LaunchAgent for this daemon exists at all.
    public var isRegistered: Bool {
        let agents = Paths.home.appending(path: "Library/LaunchAgents")
        return knownLabels.contains {
            FileManager.default.fileExists(atPath: agents.appending(path: "\($0).plist").path)
        }
    }

    /// How to install the daemon with Homebrew.
    public var installCommand: String {
        switch self {
        case .yabai: "brew install asmvik/formulae/yabai"
        case .skhd: "brew install asmvik/formulae/skhd"
        case .sketchybar: "brew install FelixKratz/formulae/sketchybar"
        case .borders: "brew install FelixKratz/formulae/borders"
        }
    }

    /// How to register the LaunchAgent. yabai and skhd manage their own.
    public var startCommand: String {
        switch self {
        case .yabai: "yabai --start-service"
        case .skhd: "skhd --start-service"
        case .sketchybar: "brew services start sketchybar"
        case .borders: "macarchy services"
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
