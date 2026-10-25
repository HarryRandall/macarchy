import Foundation

extension LegacyLayout {
    /// The new folder as startup files and shortcuts spell it: through `$HOME`
    /// so it survives a renamed account, inside double quotes for the space.
    static let rootInShell = "$HOME/Library/Application Support/Macarchy"

    /// Shell text carried over from the earlier version with every path into
    /// `~/.config/macarchy` pointed at the new folder, and how many it changed.
    ///
    /// Earlier defaults ran the command as
    /// `"$HOME/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy"`, and
    /// people copied that into their own shortcuts and keep regions. The link
    /// `move` leaves keeps those working until uninstall, so rewriting is for
    /// the long run, and a spelling it cannot rewrite safely, such as one
    /// inside single quotes, is left for the link to serve. Accepted
    /// spellings: `$HOME`, `${HOME}`, `~` and the home folder itself, quoted
    /// or not. Comments are left alone, and an unquoted path is quoted.
    public static func rewritingOldPaths(
        _ text: String, home: String = Paths.home.path
    )
        -> (text: String, changed: Int)
    {
        var scanner = OldPathScanner(text: text, home: home)
        scanner.run()
        return (String(scanner.output), scanner.changed)
    }

    /// Whether `text` still names the old folder somewhere, after rewriting.
    static func mentionsOldFolder(_ text: String) -> Bool {
        text.contains(".config/macarchy")
    }
}

/// Walks shell text tracking quotes and comments, the way the shell reads it,
/// so paths are only rewritten where the result means the same thing.
private struct OldPathScanner {
    let scalars: [Unicode.Scalar]
    let spellings: [[Unicode.Scalar]]
    var output = String.UnicodeScalarView()
    var changed = 0
    private var index = 0
    private var quote: Unicode.Scalar?

    private static let old = Array("/.config/macarchy".unicodeScalars)
    private static let metacharacters = Set(" \t\n;|&()<>\"'`".unicodeScalars)
    private static let root = Array(LegacyLayout.rootInShell.unicodeScalars)

    init(text: String, home: String) {
        scalars = Array(text.unicodeScalars)
        spellings = ["$HOME", "${HOME}", home].map { Array($0.unicodeScalars) }
    }

    mutating func run() {
        while index < scalars.count {
            let handled =
                switch quote {
                case "'": singleQuoted()
                case "\"": doubleQuoted()
                default: unquoted()
                }
            if !handled {
                output.append(scalars[index])
                index += 1
            }
        }
    }

    /// Nothing expands inside single quotes, so nothing is rewritten.
    private mutating func singleQuoted() -> Bool {
        if scalars[index] == "'" { quote = nil }
        return false
    }

    private mutating func doubleQuoted() -> Bool {
        if escaped() { return true }
        if scalars[index] == "\"" {
            quote = nil
            return false
        }
        guard let length = match(tilde: false) else { return false }
        output.append(contentsOf: Self.root)
        changed += 1
        index += length
        return true
    }

    private mutating func unquoted() -> Bool {
        if escaped() { return true }
        let character = scalars[index]
        if character == "#", wordStart {
            while index < scalars.count, scalars[index] != "\n" {
                output.append(scalars[index])
                index += 1
            }
            return true
        }
        if character == "'" || character == "\"" {
            quote = character
            return false
        }
        guard wordStart, let length = match(tilde: true) else { return false }
        // The rest of the word goes inside the quotes; a quoted part that
        // follows joins on, as the shell joins words.
        var end = index + length
        while end < scalars.count, !Self.metacharacters.contains(scalars[end]),
            scalars[end] != "\\"
        {
            end += 1
        }
        output.append("\"")
        output.append(contentsOf: Self.root)
        output.append(contentsOf: scalars[(index + length)..<end])
        output.append("\"")
        changed += 1
        index = end
        return true
    }

    /// Copies a backslash and the character it escapes.
    private mutating func escaped() -> Bool {
        guard scalars[index] == "\\", index + 1 < scalars.count else { return false }
        output.append(scalars[index])
        output.append(scalars[index + 1])
        index += 2
        return true
    }

    private var wordStart: Bool {
        index == 0 || Self.metacharacters.contains(scalars[index - 1])
            || scalars[index - 1] == "="
    }

    private func starts(with word: [Unicode.Scalar], at position: Int) -> Bool {
        position + word.count <= scalars.count
            && Array(scalars[position..<position + word.count]) == word
    }

    /// The length of a home spelling and the old folder here, ending where
    /// the path does.
    private func match(tilde: Bool) -> Int? {
        for spelling in spellings + (tilde ? [["~"]] : [])
        where starts(with: spelling, at: index) {
            let end = index + spelling.count
            guard starts(with: Self.old, at: end) else { continue }
            let after = end + Self.old.count
            if after == scalars.count || scalars[after] == "/"
                || Self.metacharacters.contains(scalars[after])
            {
                return after - index
            }
        }
        return nil
    }
}
