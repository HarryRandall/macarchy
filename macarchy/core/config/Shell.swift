import Foundation

/// Shell quoting for paths embedded in generated commands.
public enum Shell {
    /// Single-quotes `text` for POSIX shells, so spaces, `$` and quotes in a
    /// path are taken literally.
    public static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
