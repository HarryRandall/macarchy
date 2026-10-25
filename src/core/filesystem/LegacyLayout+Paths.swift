import Foundation

extension LegacyLayout {
    /// The new folder as startup files and shortcuts spell it: through `$HOME`
    /// so it survives a renamed account, inside double quotes for the space.
    static let rootInShell = "$HOME/Library/Application Support/Macarchy"

    /// The outcome of pointing carried text at the new folder.
    struct Rewrite: Equatable {
        var text: String
        /// Paths pointed at the new folder.
        var changed: Int
        /// Paths left as written because the rewritten text would not parse.
        var unsafe: Int
    }

    /// Shell text carried over from the earlier version with every path into
    /// `~/.config/macarchy` pointed at the new folder, and how many it changed.
    ///
    /// Earlier defaults ran the command as
    /// `"$HOME/.config/macarchy/Macarchy.app/Contents/MacOS/macarchy"`, and
    /// people copied that into their own shortcuts and keep regions. The link
    /// `move` leaves keeps those working until cleaning up, so rewriting is for
    /// the long run, and a spelling it cannot rewrite safely, such as one
    /// inside single quotes, is left for the link to serve. Accepted
    /// spellings: `$HOME`, `${HOME}`, `~` and the home folder itself, quoted
    /// or not. Comments are left alone; see `OldPathScanner` for quoting.
    public static func rewritingOldPaths(
        _ text: String, home: String = Paths.home.path
    )
        -> (text: String, changed: Int)
    {
        rewritingOldPaths(text, home: home, mappings: [.legacyRoot])
    }

    /// `text` with every path a mapping names pointed at its new place.
    static func rewritingOldPaths(
        _ text: String, home: String, mappings: [OldPathScanner.Mapping]
    ) -> (text: String, changed: Int) {
        var scanner = OldPathScanner(text: text, home: home, mappings: mappings)
        scanner.run()
        return (scanner.text, scanner.changed)
    }

    /// A startup file's lines rewritten as a whole, or left as written when
    /// the result would not parse as bash.
    static func rewritingOldPaths(
        inScript text: String, home: String = Paths.home.path,
        mappings: [OldPathScanner.Mapping] = [.legacyRoot], shell: String = "/bin/bash"
    ) async
        -> Rewrite
    {
        let rewritten = rewritingOldPaths(text, home: home, mappings: mappings)
        guard rewritten.changed != 0 else { return Rewrite(text: text, changed: 0, unsafe: 0) }
        guard await Setup.syntaxProblem(rewritten.text, shell: shell) == nil else {
            return Rewrite(text: text, changed: 0, unsafe: rewritten.changed)
        }
        return Rewrite(text: rewritten.text, changed: rewritten.changed, unsafe: 0)
    }

    /// skhd text with each shortcut's command rewritten on its own. skhd
    /// hands a command to the shell, so a command whose rewritten form would
    /// not parse is left as written; the rest of the file is not shell.
    static func rewritingOldPaths(
        inShortcuts text: String, home: String = Paths.home.path,
        mappings: [OldPathScanner.Mapping] = [.legacyRoot]
    )
        async -> Rewrite
    {
        let lines = text.components(separatedBy: "\n")
        var result = Rewrite(text: "", changed: 0, unsafe: 0)
        var output: [String] = []
        var start = 0
        while start < lines.count {
            let end = SkhdConfig.logicalEnd(lines, from: start)
            let logical = lines[start...end].joined(separator: "\n")
            start = end + 1
            guard let colon = commandStart(in: logical) else {
                output.append(logical)
                continue
            }
            let command = String(logical[colon...])
            let rewritten = await rewritingOldPaths(
                inScript: command, home: home, mappings: mappings)
            output.append(String(logical[..<colon]) + rewritten.text)
            result.changed += rewritten.changed
            result.unsafe += rewritten.unsafe
        }
        result.text = output.joined(separator: "\n")
        return result
    }

    /// Where the command starts in one logical skhd line: after the first
    /// `:` outside double quotes, which name applications in a per-app list.
    /// Comments, options and mode declarations have none.
    static func commandStart(in line: String) -> String.Index? {
        let trimmed = line.drop { $0 == " " || $0 == "\t" }
        guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("."), !trimmed.hasPrefix("::")
        else { return nil }
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if !quoted, line[index] == ":" { return line.index(after: index) }
        }
        return nil
    }

    /// Whether `text` still names the old folder somewhere, after rewriting.
    static func mentionsOldFolder(_ text: String) -> Bool {
        text.contains(".config/macarchy")
    }
}
