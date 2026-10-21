import Macarchy

/// Source comments name individual actions; a shared comment names the group.
enum ShortcutPresentation {
    static func label(_ binding: SkhdBinding, groupCount: Int) -> String {
        if groupCount == 1, let section = binding.section, !section.isEmpty { return section }
        if let label = knownCommand(binding.command) { return label }
        if !binding.command.isEmpty { return binding.command }
        return binding.appOverrides.isEmpty ? "Custom shortcut" : "Per-app action"
    }

    /// Recognise complete known commands, never infer meaning from a substring
    /// inside arbitrary shell code. Unrecognised commands remain literal.
    private static func knownCommand(_ command: String) -> String? {
        let directions = [("west", "left"), ("east", "right"), ("north", "up"), ("south", "down")]
        for (native, title) in directions {
            if command == "yabai -m window --focus \(native)" { return "Focus \(title)" }
            if command == "yabai -m window --swap \(native); yabai -m window --focus \(native)" {
                return "Swap \(title) and follow"
            }
        }
        for index in 1...20 {
            if command == "yabai -m space --focus \(index)" {
                return "Switch to workspace \(index)"
            }
            if command == "yabai -m window --space \(index)" { return "Move to workspace \(index)" }
            if command == "yabai -m window --space \(index); yabai -m space --focus \(index)" {
                return "Move to workspace \(index) and follow"
            }
        }
        let media = [
            ("playpause", "Play or pause Spotify"), ("next track", "Next track in Spotify"),
            ("previous track", "Previous track in Spotify")
        ]
        for (action, title) in media
        where command
            == "/usr/bin/pgrep -x Spotify >/dev/null && /usr/bin/osascript -e 'tell application \"Spotify\" to \(action)'"
        {
            return title
        }
        return nil
    }
}
