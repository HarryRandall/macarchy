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
    public static func rewritingOldPaths(_ text: String, home: String = Paths.home.path)
        -> (text: String, count: Int)
    {
        let scalars = Array(text.unicodeScalars)
        var output = String.UnicodeScalarView()
        var count = 0
        var index = 0
        var quote: Unicode.Scalar?
        let old = Array("/.config/macarchy".unicodeScalars)
        let metacharacters = Set(" \t\n;|&()<>\"'`".unicodeScalars)

        func starts(with word: [Unicode.Scalar], at position: Int) -> Bool {
            position + word.count <= scalars.count
                && Array(scalars[position..<position + word.count]) == word
        }
        /// The length of a home spelling and the old folder at `position`,
        /// ending where the path does.
        func match(at position: Int, tilde: Bool) -> Int? {
            var spellings = ["$HOME", "${HOME}", home].map { Array($0.unicodeScalars) }
            if tilde { spellings.append(["~"]) }
            for spelling in spellings where starts(with: spelling, at: position) {
                let end = position + spelling.count
                guard starts(with: old, at: end) else { continue }
                let after = end + old.count
                if after == scalars.count || scalars[after] == "/"
                    || metacharacters.contains(scalars[after])
                {
                    return after - position
                }
            }
            return nil
        }
        func wordStart(_ position: Int) -> Bool {
            position == 0 || metacharacters.contains(scalars[position - 1])
                || scalars[position - 1] == "="
        }

        while index < scalars.count {
            let character = scalars[index]
            switch quote {
            case "'":
                if character == "'" { quote = nil }
            case "\"":
                if character == "\\", index + 1 < scalars.count {
                    output.append(character)
                    output.append(scalars[index + 1])
                    index += 2
                    continue
                }
                if character == "\"" {
                    quote = nil
                } else if let length = match(at: index, tilde: false) {
                    output.append(contentsOf: rootInShell.unicodeScalars)
                    count += 1
                    index += length
                    continue
                }
            default:
                if character == "\\", index + 1 < scalars.count {
                    output.append(character)
                    output.append(scalars[index + 1])
                    index += 2
                    continue
                }
                if character == "#", wordStart(index) {
                    while index < scalars.count, scalars[index] != "\n" {
                        output.append(scalars[index])
                        index += 1
                    }
                    continue
                }
                if character == "'" || character == "\"" {
                    quote = character
                } else if wordStart(index), let length = match(at: index, tilde: true) {
                    // The rest of the word goes inside the quotes; a quoted
                    // part that follows joins on, as the shell joins words.
                    var end = index + length
                    while end < scalars.count, !metacharacters.contains(scalars[end]),
                        scalars[end] != "\\"
                    {
                        end += 1
                    }
                    output.append("\"")
                    output.append(contentsOf: rootInShell.unicodeScalars)
                    output.append(contentsOf: scalars[(index + length)..<end])
                    output.append("\"")
                    count += 1
                    index = end
                    continue
                }
            }
            output.append(character)
            index += 1
        }
        return (String(output), count)
    }

    /// Whether `text` still names the old folder somewhere, after rewriting.
    static func mentionsOldFolder(_ text: String) -> Bool {
        text.contains(".config/macarchy")
    }
}
