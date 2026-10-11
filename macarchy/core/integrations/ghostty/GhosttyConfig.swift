import Foundation

/// Points Ghostty at the active theme's colours without rewriting the user's config.
///
/// The user's file gains one `config-file` line, which Ghostty loads after the
/// rest, so the theme wins without any of their own settings being touched.
/// Removing that line is the whole uninstall.
public enum GhosttyConfig {
    public static var configURL: URL { Paths.home.appending(path: ".config/ghostty/config") }
    public static var themeURL: URL { Paths.generatedDirectory.appending(path: "ghostty.conf") }

    static let comment = "# Theme colours from Macarchy"

    /// `?` makes the include optional, so Ghostty still starts if the file is gone.
    static var includeLine: String { "config-file = ?\(themeURL.path)" }

    public static func hasInclude(_ config: String) -> Bool {
        config.split(separator: "\n").contains { isInclude($0) }
    }

    /// Appends the include once; an existing one is left where it is.
    public static func addingInclude(to config: String) -> String {
        guard !hasInclude(config) else { return config }
        var text = config
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        if !text.isEmpty { text += "\n" }
        return text + comment + "\n" + includeLine + "\n"
    }

    public static func removingInclude(from config: String) -> String {
        config.components(separatedBy: "\n")
            .filter { !isInclude(Substring($0)) && $0 != comment }
            .joined(separator: "\n")
    }

    private static func isInclude(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("config-file") else { return false }
        return trimmed.hasSuffix(themeURL.path)
    }
}
