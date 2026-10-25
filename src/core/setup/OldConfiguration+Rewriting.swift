import Foundation

/// Pointing the person's Neovim and Ghostty files at the new folder. Shell
/// text goes through `OldPathScanner`; these are not shell.
extension OldConfiguration {
    /// The new folder after a home spelling.
    static let newRootSuffix = "/Library/Application Support/Macarchy"
    static let oldRootSuffix = "/.config/macarchy"

    /// Every way a string may start with the old folder, longest first. The
    /// last is the part after `os.getenv("HOME") ..`.
    static func oldRootPrefixes(home: String) -> [String] {
        ["${HOME}", "$HOME", home, "~"].map { $0 + oldRootSuffix } + [oldRootSuffix]
    }

    /// `value` with the old folder at its start pointed at the new one, when
    /// it is a path and nothing else: no spaces or quotes follow, which
    /// could mean it is handed to a shell that would split the new name.
    static func pointingPath(_ value: Substring, home: String) -> String? {
        for prefix in oldRootPrefixes(home: home) where value.hasPrefix(prefix) {
            let rest = value.dropFirst(prefix.count)
            guard rest.isEmpty || rest.hasPrefix("/"),
                !rest.contains(where: { $0.isWhitespace || "\"'\\`$;|&".contains($0) })
            else { return nil }
            return String(prefix.dropLast(oldRootSuffix.count)) + newRootSuffix + String(rest)
        }
        return nil
    }

    /// Lua with each string that holds only a path into the old folder
    /// pointed at the new one. Comments and long strings stay as written.
    static func rewritingLua(_ text: String, home: String) -> (text: String, changed: Int) {
        let characters = Array(text)
        var output = ""
        var changed = 0
        var index = 0
        func longBracket(at start: Int) -> Int? {
            guard start < characters.count, characters[start] == "[" else { return nil }
            var cursor = start + 1
            while cursor < characters.count, characters[cursor] == "=" { cursor += 1 }
            return cursor < characters.count && characters[cursor] == "[" ? cursor - start - 1 : nil
        }
        func copyLong(from start: Int, level: Int) {
            let close = "]" + String(repeating: "=", count: level) + "]"
            var cursor = start
            while cursor < characters.count {
                if String(characters[cursor..<min(cursor + close.count, characters.count)]) == close {
                    cursor += close.count
                    break
                }
                cursor += 1
            }
            output += String(characters[index..<cursor])
            index = cursor
        }
        while index < characters.count {
            let character = characters[index]
            if character == "-", index + 1 < characters.count, characters[index + 1] == "-" {
                if let level = longBracket(at: index + 2) {
                    copyLong(from: index + 2 + level + 2, level: level)
                } else {
                    var cursor = index
                    while cursor < characters.count, characters[cursor] != "\n" { cursor += 1 }
                    output += String(characters[index..<cursor])
                    index = cursor
                }
                continue
            }
            if let level = longBracket(at: index) {
                copyLong(from: index + level + 2, level: level)
                continue
            }
            guard character == "\"" || character == "'" else {
                output.append(character)
                index += 1
                continue
            }
            var cursor = index + 1
            var escaped = false
            while cursor < characters.count, characters[cursor] != character,
                characters[cursor] != "\n"
            {
                if characters[cursor] == "\\" {
                    escaped = true
                    cursor += 1
                }
                cursor += 1
            }
            let end = min(cursor, characters.count)
            let content = String(characters[(index + 1)..<end])
            if !escaped, end < characters.count, characters[end] == character,
                let pointed = pointingPath(Substring(content), home: home)
            {
                output += String(character) + pointed + String(character)
                changed += 1
            } else {
                output += String(characters[index..<min(end + 1, characters.count)])
            }
            index = end + 1
        }
        return (output, changed)
    }

    /// Ghostty config with each `config-file` that names the old folder
    /// pointed at the new one. Ghostty reads the rest of the line as the
    /// path, spaces included.
    static func rewritingGhostty(_ text: String, home: String) -> (text: String, changed: Int) {
        var changed = 0
        let lines = text.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            guard trimmed.hasPrefix("config-file"), let equals = line.firstIndex(of: "=") else {
                return line
            }
            var value = line[line.index(after: equals)...].drop { $0 == " " || $0 == "\t" }
            let lead = line[..<value.startIndex]
            var quote = ""
            if value.hasPrefix("\"") {
                quote = "\""
                value = value.dropFirst()
            }
            var optional = ""
            if value.hasPrefix("?") {
                optional = "?"
                value = value.dropFirst()
            }
            let closing = quote.isEmpty ? "" : "\""
            var path = value
            if !closing.isEmpty, path.hasSuffix(closing) { path = path.dropLast() }
            let trailing = path.reversed().prefix { $0 == " " || $0 == "\t" }.count
            let bare = path.dropLast(trailing)
            for prefix in oldRootPrefixes(home: home).dropLast() where bare.hasPrefix(prefix) {
                let rest = bare.dropFirst(prefix.count)
                guard rest.isEmpty || rest.hasPrefix("/") else { continue }
                changed += 1
                let spelling = String(prefix.dropLast(oldRootSuffix.count))
                return String(lead) + quote + optional + spelling + newRootSuffix + String(rest)
                    + closing
            }
            return line
        }
        return (lines.joined(separator: "\n"), changed)
    }
}
