import Foundation

extension StartupConfiguration {
    /// yabai config keys the app owns, with the flat settings key each
    /// resolves from and the value used if nothing has been set.
    public static func envName(forYabaiKey key: String) -> String? {
        yabaiKeys.first { $0.key == key }?.env
    }

    public static let yabaiKeys: [SettingKey] = [
        SettingKey(key: "layout", env: "YABAI_LAYOUT", fallback: "bsp"),
        SettingKey(key: "window_insertion_point", env: "YABAI_INSERTION_POINT", fallback: "last"),
        SettingKey(
            key: "window_placement", env: "YABAI_WINDOW_PLACEMENT", fallback: "second_child"),
        SettingKey(key: "split_type", env: "YABAI_SPLIT_TYPE", fallback: "auto"),
        SettingKey(key: "auto_balance", env: "YABAI_AUTO_BALANCE", fallback: "off"),
        SettingKey(
            key: "insert_feedback_color", env: "YABAI_INSERT_FEEDBACK_COLOR", fallback: "0x01000000"
        ),
        SettingKey(key: "top_padding", env: "YABAI_TOP_PADDING", fallback: "8"),
        SettingKey(key: "bottom_padding", env: "YABAI_BOTTOM_PADDING", fallback: "8"),
        SettingKey(key: "left_padding", env: "YABAI_LEFT_PADDING", fallback: "8"),
        SettingKey(key: "right_padding", env: "YABAI_RIGHT_PADDING", fallback: "8"),
        SettingKey(key: "window_gap", env: "YABAI_WINDOW_GAP", fallback: "8"),
        SettingKey(key: "mouse_follows_focus", env: "YABAI_MOUSE_FOLLOWS_FOCUS", fallback: "off"),
        SettingKey(key: "mouse_modifier", env: "YABAI_MOUSE_MODIFIER", fallback: "ctrl"),
        SettingKey(key: "mouse_action1", env: "YABAI_MOUSE_ACTION1", fallback: "move"),
        SettingKey(key: "mouse_action2", env: "YABAI_MOUSE_ACTION2", fallback: "resize"),
        SettingKey(key: "mouse_drop_action", env: "YABAI_MOUSE_DROP_ACTION", fallback: "stack")
    ]

    /// Splits an existing yabairc into settings Macarchy now owns and lines it
    /// keeps verbatim. A line moves only when it is a plain, top-level
    /// `yabai -m config <key> <value>` for a key in `yabaiKeys` with a literal
    /// value. Anything inside a loop, conditional, function or continued line
    /// stays exactly as written, because moving it would change when it runs.
    public static func adoptYabai(_ text: String) -> (values: [String: String], kept: String) {
        var values: [String: String] = [:]
        var kept: [String] = []
        var depth = 0
        var continued = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            defer {
                depth = max(0, depth + nesting(trimmed))
                continued = trimmed.hasSuffix("\\")
            }
            if trimmed.hasPrefix("#!") { continue }
            if depth == 0, !continued, let (env, value) = literalConfig(trimmed) {
                values[env] = value
                continue
            }
            kept.append(line)
        }
        return (values, tidy(kept))
    }

    /// `yabai -m config key value` with a value free of shell expansion.
    private static func literalConfig(_ line: String) -> (String, String)? {
        let words = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count == 5, words[0] == "yabai", words[1] == "-m", words[2] == "config",
            let env = envName(forYabaiKey: words[3])
        else { return nil }
        let value = words[4].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard value.range(of: "^[A-Za-z0-9_.:-]+$", options: .regularExpression) != nil else {
            return nil
        }
        return (env, value)
    }

    /// How much a line opens or closes shell blocks. Deliberately cautious:
    /// anything that might open a block keeps later lines in place.
    private static func nesting(_ line: String) -> Int {
        guard !line.hasPrefix("#") else { return 0 }
        let words = line.split(whereSeparator: { $0 == " " || $0 == ";" || $0 == "\t" })
            .map(String.init)
        var change = 0
        for word in words {
            switch word {
            case "if", "for", "while", "until", "case", "{", "(": change += 1
            case "fi", "done", "esac", "}", ")": change -= 1
            default:
                if word.hasSuffix("()") || word.hasSuffix("{") { change += 1 }
                if word.hasPrefix("}") { change -= 1 }
            }
        }
        return change
    }

    @discardableResult
    public func generateYabaiRC(adopting: String? = nil) -> GeneratedFile.Outcome {
        let file = Self.yabairc
        let content =
            Self.header("Layout, rules and signals come from the Layout and Rules pages.")
            + "\(Paths.cliInShell) startup yabai\n\n"
            + region(yours(file, adopting: adopting)) + "\n"
        return file.write(content, reason: "layout startup changed")
    }
}
