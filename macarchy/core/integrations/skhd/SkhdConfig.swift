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
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)
            defer { index += 1 }

            if line.isEmpty { pendingComment = []; continue }

            if line.hasPrefix("#") {
                let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
                if !body.isEmpty { pendingComment.append(body) }
                continue
            }

            // A comment block directly above a binding names the section.
            if !pendingComment.isEmpty {
                section = pendingComment.joined(separator: " ")
                pendingComment = []
            }

            guard
                let parsed = parseBinding(
                    line, at: index, section: section, lines: lines, cursor: &index)
            else { continue }
            bindings.append(parsed)
        }
        return bindings
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

    private static func parseBinding(
        _ line: String, at lineIndex: Int, section: String?,
        lines: [String], cursor: inout Int
    ) -> SkhdBinding? {
        guard let split = split(line) else { return nil }
        let (modifiers, key) = splitKeySpec(split.keySpec)
        guard !key.isEmpty else { return nil }

        // App-specific form: `<keyspec> [` … `]`, optionally with `->`.
        if split.isBlock {
            var overrides: [SkhdBinding.AppOverride] = []
            var scan = cursor + 1
            var closed = false
            while scan < lines.count {
                let entry = lines[scan].trimmingCharacters(in: .whitespaces)
                scan += 1
                if entry.hasPrefix("]") { closed = true; break }
                guard let colon = entry.firstIndex(of: ":") else { continue }
                let app = entry[entry.startIndex..<colon]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \"\t"))
                let command = entry[entry.index(after: colon)...].trimmingCharacters(
                    in: .whitespaces)
                if !app.isEmpty { overrides.append(.init(app: app, command: command)) }
            }
            cursor = scan - 1
            // skhd rejects an unterminated block; its body must not surface as
            // separate bindings either.
            guard closed else { return nil }
            return SkhdBinding(
                id: lineIndex, endLine: cursor, source: Array(lines[lineIndex...cursor]),
                modifiers: modifiers, key: key,
                command: overrides.first(where: { $0.app == "*" })?.command ?? "",
                section: section, passthrough: split.passthrough, appOverrides: overrides)
        }

        // Standard form. Commands routinely contain colons (osascript, URLs), so
        // only the first one separates the key spec from the command.
        let command = line[line.index(after: split.rest)...].trimmingCharacters(
            in: .whitespaces)
        guard !command.isEmpty else { return nil }
        return SkhdBinding(
            id: lineIndex, endLine: lineIndex, source: [lines[lineIndex]],
            modifiers: modifiers, key: key, command: command,
            section: section, passthrough: split.passthrough, appOverrides: [])
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
    /// line numbering and the change can be read back later.
    public static func disable(_ text: String, line index: Int) -> String? {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index),
            !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("#")
        else { return nil }
        lines[index] = "# " + lines[index]
        return lines.joined(separator: "\n")
    }

    /// Comments out every line of `binding`, including a per-app block's body
    /// and closing bracket, which would otherwise stay live or break parsing.
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
