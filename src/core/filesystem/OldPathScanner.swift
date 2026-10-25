import Foundation

/// Walks shell text the way the shell reads it, so a path into
/// `~/.config/macarchy` is only rewritten where the result means the same.
///
/// It keeps a stack of contexts, because quotes nest: a double-quoted
/// string can hold `$( ... )` or backticks, which hold commands with quotes
/// of their own. Where the path is already inside double quotes, or in a
/// here-document body that expands, the new folder goes in as it is: its
/// only special character is the space, which double quotes keep. Where it
/// is unquoted, the new folder is quoted and anything that expands after it,
/// such as a glob or a brace, stays outside the quotes so it still expands.
/// Single quotes, quoted here-documents, `${ ... }` and arithmetic are left
/// as they are, for the link at the old path to serve.
struct OldPathScanner {
    private enum Frame: Equatable {
        /// The top level, `$( ... )` with the parentheses and `case`
        /// statements opened inside it, and backticks: commands, where a
        /// path is unquoted. A `)` ending a case pattern does not close `$(`.
        case top
        case substitution(depth: Int, cases: Int)
        case backtick
        case double
        case single
        /// `$'...'`, where a backslash escapes the closing quote.
        case ansi
        case parameter
        case arithmetic(depth: Int)
        case heredoc(Heredoc)

        var isCommand: Bool {
            switch self {
            case .top, .substitution, .backtick: true
            default: false
            }
        }
    }

    let scalars: [Unicode.Scalar]
    private let spellings: [[Unicode.Scalar]]
    private let home: [Unicode.Scalar]
    private(set) var output = String.UnicodeScalarView()
    private(set) var changed = 0
    private var index = 0
    private var frames: [Frame] = [.top]
    private var pending: [Heredoc] = []
    /// Where the innermost `$(` or backtick started its commands, which is a
    /// word start although the character before it is not a separator.
    private var commandStart = 0

    private static let old = Array("/.config/macarchy".unicodeScalars)
    static let metacharacters = Set(" \t\n;|&()<>\"'`".unicodeScalars)
    private static let separators = Set(" \t\n;|&()<>=".unicodeScalars)
    /// Characters that mean the same inside double quotes as outside, so an
    /// unquoted path can take them into its quotes.
    private static let plain = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-+,:@%".unicodeScalars)
    private static let root = Array(LegacyLayout.rootInShell.unicodeScalars)

    init(text: String, home: String) {
        scalars = Array(text.unicodeScalars)
        spellings = ["$HOME", "${HOME}"].map { Array($0.unicodeScalars) }
        self.home = Array(home.unicodeScalars)
    }

    var text: String { String(output) }

    mutating func run() {
        while index < scalars.count {
            let handled =
                switch frames.last ?? .top {
                case .top, .substitution, .backtick: command()
                case .double: doubleQuoted()
                case .single: closes("'")
                case .ansi: escaped() || closes("'")
                case .parameter: parameter()
                case .arithmetic(let depth): arithmetic(depth)
                case .heredoc(let heredoc): body(heredoc)
                }
            if !handled { copy(1) }
        }
    }

    // MARK: - Contexts

    private mutating func command() -> Bool {
        if escaped() { return true }
        if wordStart {
            if let length = match(tilde: true) {
                rewriteUnquoted(length)
                return true
            }
            if startsWord() { return true }
        }
        switch scalars[index] {
        case "\n":
            copy(1)
            frames += pending.reversed().map { .heredoc($0) }
            pending = []
        case "'": push(.single, 1)
        case "\"": push(.double, 1)
        case "`": return backtick()
        case "$" where starts(with: "$'"): push(.ansi, 2)
        case "(", ")": parenthesis()
        case "<" where starts(with: "<<") && !starts(with: "<<<"): return heredocOperator()
        default: return expansion()
        }
        return true
    }

    /// Opens backticks, or closes the ones this is inside.
    private mutating func backtick() -> Bool {
        guard frames.last != .backtick else {
            frames.removeLast()
            return false
        }
        push(.backtick, 1)
        return true
    }

    /// What only counts at the start of a word: a comment, an arithmetic
    /// command, and the `case` and `esac` that bracket case patterns.
    private mutating func startsWord() -> Bool {
        switch scalars[index] {
        case "#":
            while index < scalars.count, scalars[index] != "\n" { copy(1) }
        case "(" where starts(with: "(("): push(.arithmetic(depth: 0), 2)
        case "c" where keyword("case"): caseKeyword(1, 4)
        case "e" where keyword("esac"): caseKeyword(-1, 4)
        default: return false
        }
        return true
    }

    private mutating func doubleQuoted() -> Bool {
        if escaped() { return true }
        if let length = match(tilde: false) {
            rewriteQuoted(length)
            return true
        }
        if scalars[index] == "\"" {
            frames.removeLast()
            return false
        }
        if scalars[index] == "`" {
            push(.backtick, 1)
            return true
        }
        return expansion()
    }

    /// `${ ... }` is left as written; its quotes are tracked so its end is found.
    private mutating func parameter() -> Bool {
        if escaped() { return true }
        switch scalars[index] {
        case "}":
            frames.removeLast()
            return false
        case "\"": push(.double, 1)
        case "'" where frames.dropLast().last?.isCommand == true: push(.single, 1)
        case "`": push(.backtick, 1)
        default: return expansion()
        }
        return true
    }

    private mutating func arithmetic(_ depth: Int) -> Bool {
        switch scalars[index] {
        case "(": frames[frames.count - 1] = .arithmetic(depth: depth + 1)
        case ")" where depth > 0: frames[frames.count - 1] = .arithmetic(depth: depth - 1)
        case ")" where starts(with: "))"):
            frames.removeLast()
            copy(2)
            return true
        default: break
        }
        return false
    }

    /// A here-document body. Quotes mean nothing in it, and it expands like
    /// a double-quoted string unless its delimiter was quoted.
    private mutating func body(_ heredoc: Heredoc) -> Bool {
        if index == 0 || scalars[index - 1] == "\n",
            let length = heredoc.closingLine(in: scalars, at: index)
        {
            copy(length)
            frames.removeLast()
            return true
        }
        if heredoc.literal { return false }
        if escaped() { return true }
        if let length = match(tilde: false) {
            rewriteQuoted(length)
            return true
        }
        if scalars[index] == "`" {
            push(.backtick, 1)
            return true
        }
        return expansion()
    }

    /// `$( ... )`, `$(( ... ))` and `${ ... }`, which open a context
    /// wherever they appear.
    private mutating func expansion() -> Bool {
        if starts(with: "$((") {
            push(.arithmetic(depth: 0), 3)
        } else if starts(with: "$(") {
            push(.substitution(depth: 0, cases: 0), 2)
        } else if starts(with: "${") {
            push(.parameter, 2)
        } else {
            return false
        }
        return true
    }

    private mutating func parenthesis() {
        guard case .substitution(let depth, let cases) = frames.last else {
            copy(1)
            return
        }
        if scalars[index] == "(" {
            frames[frames.count - 1] = .substitution(depth: depth + 1, cases: cases)
        } else if depth > 0 {
            frames[frames.count - 1] = .substitution(depth: depth - 1, cases: cases)
        } else if cases == 0 {
            frames.removeLast()
        }
        copy(1)
    }

    private mutating func caseKeyword(_ change: Int, _ length: Int) {
        if case .substitution(let depth, let cases) = frames.last {
            frames[frames.count - 1] = .substitution(depth: depth, cases: max(0, cases + change))
        }
        copy(length)
    }

    /// Whether `word` is here as a whole word.
    private func keyword(_ word: String) -> Bool {
        let end = index + word.unicodeScalars.count
        return starts(with: word)
            && (end == scalars.count || Self.metacharacters.contains(scalars[end]))
    }

    /// `<<word` or `<<-word`: the body starts on the next line.
    private mutating func heredocOperator() -> Bool {
        guard let (heredoc, end) = Heredoc.parse(scalars, at: index) else { return false }
        pending.append(heredoc)
        copy(end - index)
        return true
    }

}

extension OldPathScanner {
    // MARK: - Rewriting

    private mutating func rewriteQuoted(_ length: Int) {
        output.append(contentsOf: Self.root)
        changed += 1
        index += length
    }

    /// Quotes the new folder and the plain rest of the word; a glob, brace
    /// or expansion after it stays unquoted, as it was.
    private mutating func rewriteUnquoted(_ length: Int) {
        var end = index + length
        while end < scalars.count, Self.plain.contains(scalars[end]) { end += 1 }
        output.append("\"")
        output.append(contentsOf: Self.root)
        output.append(contentsOf: scalars[(index + length)..<end])
        output.append("\"")
        changed += 1
        index = end
    }

    // MARK: - Reading

    private mutating func push(_ frame: Frame, _ length: Int) {
        frames.append(frame)
        copy(length)
        if frame == .backtick || frame == .substitution(depth: 0, cases: 0) {
            commandStart = index
        }
    }

    private mutating func copy(_ length: Int) {
        let end = min(index + length, scalars.count)
        output.append(contentsOf: scalars[index..<end])
        index = end
    }

    private mutating func closes(_ quote: Unicode.Scalar) -> Bool {
        if scalars[index] == quote { frames.removeLast() }
        return false
    }

    /// Copies a backslash and the character it escapes.
    private mutating func escaped() -> Bool {
        guard scalars[index] == "\\", index + 1 < scalars.count else { return false }
        copy(2)
        return true
    }

    private var wordStart: Bool {
        index == 0 || index == commandStart || Self.separators.contains(scalars[index - 1])
    }

    private func starts(with word: String) -> Bool {
        starts(with: Array(word.unicodeScalars), at: index)
    }

    private func starts(with word: [Unicode.Scalar], at position: Int) -> Bool {
        position + word.count <= scalars.count
            && Array(scalars[position..<position + word.count]) == word
    }

    /// The length of a home spelling and the old folder here, ending where
    /// the path does. The home folder written out must start a path, and
    /// `~` only counts where it expands, outside quotes.
    private func match(tilde: Bool) -> Int? {
        var candidates = spellings
        if index == 0 || !Self.plain.contains(scalars[index - 1]) { candidates.append(home) }
        if tilde { candidates.append(["~"]) }
        for spelling in candidates where starts(with: spelling, at: index) {
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
