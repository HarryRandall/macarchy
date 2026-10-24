import Foundation

/// Parser for skhd's config DSL.
///
/// skhd parses this internally and exposes nothing, and no third-party parser
/// exists, so this is ours. It lives beside the daemon it reads rather than in
/// the app because generating skhdrc later has to round-trip through the same model.
public enum SkhdConfig {
    /// Parses skhdrc into bindings, carrying the section comment each sits under.
    ///
    /// Comment lines become the current section heading, so the grouping the
    /// file already expresses by hand survives into the UI.
    public static func parse(_ text: String) -> [SkhdBinding] {
        var bindings: [SkhdBinding] = []
        var section: String?
        var pendingComment: [String] = []

        let lines = text.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            var end = logicalEnd(lines, from: index)
            defer { index = end + 1 }

            if line.isEmpty { pendingComment = []; continue }

            if line.hasPrefix("#") {
                let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if !body.isEmpty { pendingComment.append(body) }
                continue
            }

            // Options such as `.blacklist [ … ]`, `.load` and `.shell` set up
            // skhd itself. They are not shortcuts and are left as written.
            if line.hasPrefix(".") {
                pendingComment = []
                end = optionEnd(lines, from: index)
                continue
            }

            // A comment block directly above a binding names the section.
            if !pendingComment.isEmpty {
                section = pendingComment.joined(separator: " ")
                pendingComment = []
            }

            let (parsed, last) = parseBinding(lines, from: index, through: end, section: section)
            end = last
            if let parsed { bindings.append(parsed) }
        }
        return bindings
    }

    /// The last physical line of the logical line that starts at `start`.
    ///
    /// skhd reads a backslash as escaping the next character, so a command
    /// whose line ends in an odd run of backslashes carries on to the next
    /// line. A comment ends at its line break whatever it ends with.
    static func logicalEnd(_ lines: [String], from start: Int) -> Int {
        guard !lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
            return start
        }
        var end = start
        while end + 1 < lines.count,
            lines[end].reversed().prefix(while: { $0 == "\\" }).count % 2 == 1
        {
            end += 1
        }
        return end
    }

    /// The last line of the option starting at `start`: the line holding the
    /// `]` that closes a list such as `.blacklist [`, or the option's own line.
    /// An unclosed list runs to the end, as skhd would reject it anyway.
    static func optionEnd(_ lines: [String], from start: Int) -> Int {
        guard let open = unquoted("[", in: lines[start]) else { return start }
        if unquoted("]", in: String(lines[start][open...])) != nil { return start }
        var end = start + 1
        while end < lines.count {
            if unquoted("]", in: lines[end]) != nil { return end }
            end += 1
        }
        return lines.count - 1
    }

    /// The first `character` outside double quotes, so an application named
    /// with a bracket cannot end a list early.
    private static func unquoted(_ character: Character, in line: String) -> String.Index? {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if !quoted, line[index] == character { return index }
        }
        return nil
    }

    /// One logical line as skhd hands it to the shell: each escaped line break
    /// removed, everything else kept.
    static func joined(_ lines: ArraySlice<String>) -> String {
        guard let last = lines.last else { return "" }
        return lines.dropLast().map { String($0.dropLast()) }.joined() + last
    }

    /// Where a binding line splits into its key spec and the rest.
    ///
    /// The key spec never contains `:` or `[`, so the first of either ends it.
    /// Searching for `->` anywhere would match inside commands such as
    /// `echo "a -> b"` and discard part of them on rewrite.
    struct Split {
        let keySpec: String
        /// Index of the `:` or `[`, which is kept verbatim on rewrite.
        let rest: String.Index
        let isBlock: Bool
        let passthrough: Bool
    }

    static func split(_ line: String) -> Split? {
        guard let boundary = line.firstIndex(where: { $0 == ":" || $0 == "[" }) else {
            return nil
        }
        var head = line[line.startIndex..<boundary].trimmingCharacters(in: .whitespaces)
        let passthrough = head.hasSuffix("->")
        if passthrough { head = head.dropLast(2).trimmingCharacters(in: .whitespaces) }
        guard !head.isEmpty else { return nil }
        return Split(
            keySpec: head, rest: boundary, isBlock: line[boundary] == "[",
            passthrough: passthrough)
    }

    /// Parses the logical line `start...end`, and for a per-app block the
    /// lines up to its closing bracket. Returns the last line it consumed,
    /// even when there is no binding, so a broken block's body is skipped.
    private static func parseBinding(
        _ lines: [String], from start: Int, through end: Int, section: String?
    ) -> (SkhdBinding?, Int) {
        let line = joined(lines[start...end])
        guard let split = split(line) else { return (nil, end) }
        let (modifiers, key) = splitKeySpec(split.keySpec)
        guard !key.isEmpty else { return (nil, end) }

        // App-specific form: `<keyspec> [` … `]`, optionally with `->`.
        if split.isBlock {
            var overrides: [SkhdBinding.AppOverride] = []
            var scan = end + 1
            var closed = false
            while scan < lines.count {
                let entryEnd = logicalEnd(lines, from: scan)
                let entry = joined(lines[scan...entryEnd]).trimmingCharacters(in: .whitespaces)
                scan = entryEnd + 1
                if entry.hasPrefix("]") { closed = true; break }
                guard !entry.hasPrefix("#"), let colon = entry.firstIndex(of: ":") else {
                    continue
                }
                let app = entry[entry.startIndex..<colon]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \"\t"))
                let command = entry[entry.index(after: colon)...].trimmingCharacters(
                    in: .whitespaces)
                if !app.isEmpty { overrides.append(.init(app: app, command: command)) }
            }
            let blockEnd = scan - 1
            // skhd rejects an unterminated block; its body must not surface as
            // separate bindings either.
            guard closed else { return (nil, blockEnd) }
            let binding = SkhdBinding(
                id: start, endLine: blockEnd, source: Array(lines[start...blockEnd]),
                modifiers: modifiers, key: key,
                command: overrides.first(where: { $0.app == "*" })?.command ?? "",
                section: section, passthrough: split.passthrough, appOverrides: overrides)
            return (binding, blockEnd)
        }

        // Standard form. Commands routinely contain colons (osascript, URLs), so
        // only the first one separates the key spec from the command.
        let command = line[line.index(after: split.rest)...].trimmingCharacters(
            in: .whitespaces)
        guard !command.isEmpty else { return (nil, end) }
        let binding = SkhdBinding(
            id: start, endLine: end, source: Array(lines[start...end]),
            modifiers: modifiers, key: key, command: command,
            section: section, passthrough: split.passthrough, appOverrides: [])
        return (binding, end)
    }

    /// "cmd + shift - h" → (["cmd","shift"], "h"). Media keys carry no modifier.
    private static func splitKeySpec(_ spec: String) -> ([String], String) {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard let dash = trimmed.range(of: " - ") ?? trimmed.range(of: "-", options: .backwards)
        else {
            return ([], trimmed)
        }
        let modifierPart = trimmed[trimmed.startIndex..<dash.lowerBound]
        let key = trimmed[dash.upperBound...].trimmingCharacters(in: .whitespaces)

        let modifiers =
            modifierPart
            .components(separatedBy: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return (modifiers, key)
    }
}

// MARK: - Writing

extension SkhdConfig {
    /// Renders a key spec in the form skhd parses back: `cmd + shift - h`.
    ///
    /// Modifier order is normalised so two bindings that mean the same chord
    /// read the same in the file, whatever order they were recorded in.
    public static func keySpec(modifiers: [String], key: String) -> String {
        let order = ["fn", "ctrl", "alt", "shift", "cmd", "hyper"]
        let sorted = modifiers.map { $0.lowercased() }.sorted {
            (order.firstIndex(of: $0) ?? order.count) < (order.firstIndex(of: $1) ?? order.count)
        }
        guard !sorted.isEmpty else { return key }
        return sorted.joined(separator: " + ") + " - " + key
    }

    /// Replaces the key spec on one line, keeping the command untouched.
    ///
    /// Only the part before the first `:` or `[` is rewritten, because a
    /// command routinely contains colons and arrows. Returns `nil` when the
    /// line is not a binding, so a miscounted index cannot corrupt the file.
    public static func rebind(
        _ text: String, line index: Int, modifiers: [String], key: String
    ) -> String? {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index) else { return nil }

        let line = lines[index]
        guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("#"),
            let split = split(line)
        else { return nil }
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let spec = keySpec(modifiers: modifiers, key: key) + (split.passthrough ? " ->" : "")
        lines[index] = indent + spec + " " + String(line[split.rest...])
        return lines.joined(separator: "\n")
    }

    /// Rebinds `binding`, refusing if the file no longer holds it where it was read.
    ///
    /// Another editor may have inserted lines since the page loaded; trusting
    /// the stored line number alone would then rewrite a different shortcut.
    public static func rebind(
        _ text: String, binding: SkhdBinding, modifiers: [String], key: String
    ) -> String? {
        guard matches(text, binding) else { return nil }
        return rebind(text, line: binding.id, modifiers: modifiers, key: key)
    }

    /// Comments a binding out rather than deleting it, so the file keeps its
    /// line numbering and the change can be read back later. A command
    /// continued onto later lines is commented out whole, or its tail would
    /// stay live and break the file.
    public static func disable(_ text: String, line index: Int) -> String? {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index),
            !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("#")
        else { return nil }
        for line in index...logicalEnd(lines, from: index) {
            lines[line] = "# " + lines[line]
        }
        return lines.joined(separator: "\n")
    }

    /// Comments out every line of `binding`, including a per-app block's body
    /// and closing bracket or a continued command's later lines, which would
    /// otherwise stay live or break parsing.
    public static func disable(_ text: String, binding: SkhdBinding) -> String? {
        guard matches(text, binding) else { return nil }
        var lines = text.components(separatedBy: "\n")
        for index in binding.id...binding.endLine {
            lines[index] = "# " + lines[index]
        }
        return lines.joined(separator: "\n")
    }

    static func matches(_ text: String, _ binding: SkhdBinding) -> Bool {
        let lines = text.components(separatedBy: "\n")
        guard binding.id <= binding.endLine, lines.indices.contains(binding.endLine) else {
            return false
        }
        return Array(lines[binding.id...binding.endLine]) == binding.source
    }
}
