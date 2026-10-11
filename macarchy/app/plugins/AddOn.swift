import SwiftUI

/// A tool the desktop could adopt, and what adopting it would change.
struct AddOn: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: String
    let tint: Color
    let description: String
    let detail: String
    /// What the integration would actually do, as short phrases.
    let brings: [String]
    let stage: Stage

    enum Stage: String, CaseIterable {
        case planned = "Planned"
        case exploring = "Exploring"
        case considering = "Considering"

        var tone: StatusChip.Tone {
            switch self {
            case .planned: .good
            case .exploring: .warning
            case .considering: .idle
            }
        }
    }

    static let categories = ["All", "Editor", "Terminal", "System", "Shell", "Bar"]

    static let catalogue: [Self] = [
        .init(
            id: "neovim", name: "Neovim", icon: "chevron.left.forwardslash.chevron.right",
            category: "Editor", tint: .green,
            description: "A keyboard-first editor for code and everything around it.",
            detail: "The proposed integration adds editor configuration and theme matching when "
                + "you choose to enable it.",
            brings: ["Colourscheme follows your theme", "Shared keybindings", "Managed config"],
            stage: .planned),
        .init(
            id: "btop", name: "btop", icon: "chart.xyaxis.line",
            category: "System", tint: .orange,
            description: "A closer look at CPU, memory and the work your Mac is doing.",
            detail: "The proposed integration adds a terminal system monitor with a palette that "
                + "follows your theme.",
            brings: ["Themed palette", "Menu bar launcher", "Preset layouts"],
            stage: .planned),
        .init(
            id: "fastfetch", name: "Fastfetch", icon: "terminal",
            category: "Terminal", tint: .cyan,
            description: "A compact system overview to make your terminal feel like yours.",
            detail: "The proposed integration adds a configurable system summary. It remains "
                + "separate from the core desktop controls.",
            brings: ["Themed ASCII logo", "Chosen fields", "Shell startup hook"],
            stage: .exploring),
        .init(
            id: "lazygit", name: "Lazygit", icon: "arrow.triangle.branch",
            category: "Terminal", tint: .purple,
            description: "A terminal interface for the git work you do every day.",
            detail: "The proposed integration would match its panes to your theme and open it "
                + "from a shortcut.",
            brings: ["Themed panes", "Shortcut to open", "Repo shortcuts"],
            stage: .exploring),
        .init(
            id: "yazi", name: "Yazi", icon: "folder",
            category: "Terminal", tint: .blue,
            description: "A fast file manager that lives where your hands already are.",
            detail: "The proposed integration would share your theme's colours and preview "
                + "wallpapers in place.",
            brings: ["Themed interface", "Wallpaper previews", "Opens from the bar"],
            stage: .considering),
        .init(
            id: "starship", name: "Starship", icon: "sparkles",
            category: "Shell", tint: .yellow,
            description: "A prompt that tells you where you are without being asked.",
            detail: "The proposed integration would generate a prompt using your theme's accent "
                + "and palette.",
            brings: ["Accent-matched prompt", "Generated config", "Git status"],
            stage: .planned),
        .init(
            id: "tmux", name: "tmux", icon: "rectangle.split.3x1",
            category: "Terminal", tint: .teal,
            description: "Keep sessions and panes alive between terminal windows.",
            detail: "The proposed integration would align its status line with your menu bar "
                + "and share the same colours.",
            brings: ["Status line matches bar", "Shared palette", "Session shortcuts"],
            stage: .considering),
        .init(
            id: "spotify", name: "Spotify", icon: "music.note",
            category: "Bar", tint: .green,
            description: "What is playing, in the bar, coloured like everything else.",
            detail: "The proposed integration adds a now-playing component you can build in "
                + "the menu bar editor, with playback controls and a track name that truncates "
                + "rather than pushing the rest of the bar off screen.",
            brings: ["Now-playing component", "Playback controls", "Themed to your palette"],
            stage: .planned),
        .init(
            id: "aerospace", name: "Raycast", icon: "magnifyingglass",
            category: "System", tint: .pink,
            description: "A launcher that can drive the desktop as well as open apps.",
            detail: "The proposed integration would expose Macarchy actions as commands you can "
                + "run from the launcher.",
            brings: ["Theme switching commands", "Layout commands", "Deep links"],
            stage: .considering)
    ]
}
