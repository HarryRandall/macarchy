import Foundation

/// Inlines a theme's palette into the user's ghostty config.
///
/// Ported from theme-switch's `awk | grep -Ev | grep -Ev` pipeline. The
/// transformation is kept pure — string in, string out — so it can be diffed
/// against the shell it replaces rather than trusted.
public enum GhosttyApplier {
    public static let marker = "# --- THEME COLORS "

    /// Lines the theme owns. Any of these already in the config are dropped, so
    /// switching themes cannot leave a previous theme's colours behind.
    private static let ownedKeys = [
        "background", "foreground", "cursor-color", "cursor-text",
        "selection-background", "selection-foreground", "palette", "theme"
    ]

    public static func transform(config: String, themeConf: String, themeName: String) -> String {
        var kept: [String] = []
        var pendingBlanks = 0

        for raw in config.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)

            // Everything from the previous theme block onward is replaced.
            if line.hasPrefix(marker) { break }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Blank runs are held back, so trailing blanks are dropped while
                // interior spacing survives — matching the awk's behaviour.
                pendingBlanks += 1
                continue
            }
            if isOwned(line) { continue }

            kept.append(contentsOf: Array(repeating: "", count: pendingBlanks))
            pendingBlanks = 0
            kept.append(line)
        }

        var out = kept
        out.append("")
        out.append("\(marker)(\(themeName)) ---")
        out.append(contentsOf: themeConf
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init))

        // The shell appends with `cat`, which leaves exactly one trailing newline.
        while out.last?.isEmpty == true { out.removeLast() }
        return out.joined(separator: "\n") + "\n"
    }

    private static func isOwned(_ line: String) -> Bool {
        let trimmed = line.drop { $0 == " " || $0 == "\t" }

        for key in ownedKeys where trimmed.hasPrefix(key) {
            let rest = trimmed.dropFirst(key.count).drop { $0 == " " || $0 == "\t" }
            if rest.first == "=" { return true }
        }
        // config-file references pointing into a themes directory.
        if trimmed.hasPrefix("config-file") {
            let rest = trimmed.dropFirst("config-file".count).drop { $0 == " " || $0 == "\t" }
            if rest.first == "=", rest.contains(".themes/") { return true }
        }
        return false
    }
}
