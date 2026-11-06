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

            // A binding the page disabled is listed as disabled. It is not a
            // heading, and a heading above it names its section as usual.
            if let disabled = disabledBinding(
                lines, from: index,
                section: pendingComment.isEmpty ? section : pendingComment.joined(separator: " "))
            {
                section = disabled.section
                pendingComment = []
                bindings.append(disabled)
                end = disabled.endLine
                continue
            }

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

    /// What `disable` writes before a binding's first line. The marker tells
    /// a disabled shortcut from a heading such as `# Space: switch desktops`,
    /// which would otherwise read as a bare Space binding.
    static let disabledMarker = "# disabled: "

    /// The binding that `disable` commented out, when the comment at `start`
    /// is one.
    ///
    /// The first line carries `disabledMarker` and the rest `# `, or `#` alone
    /// for an empty line, which is also what an editor that trims trailing
    /// spaces leaves of `# `. A first line with only `# ` is read as disabled
    /// when it names a modifier or a mode, so a prose comment such as
    /// `# Note: x` or `# Play: media keys below` stays a heading.
    static func disabledBinding(
        _ lines: [String], from start: Int, section: String?
    ) -> SkhdBinding? {
        let first = lines[start]
        let marked = first.hasPrefix(disabledMarker)
        guard marked || first.hasPrefix("# ") else { return nil }
        var run = [String(first.dropFirst(marked ? disabledMarker.count : 2))]
        for line in lines[(start + 1)...] {
            guard let body = uncommented(line) else { break }
            run.append(body)
        }
        let (parsed, last) = parseBinding(
            run, from: 0, through: logicalEnd(run, from: 0), section: section)
        guard let parsed, isChord(parsed, marked: marked) else { return nil }
        return SkhdBinding(
            id: start, endLine: start + last, source: Array(lines[start...(start + last)]),
            modifiers: parsed.modifiers, key: parsed.key, command: parsed.command,
            section: section, passthrough: parsed.passthrough,
            appOverrides: parsed.appOverrides, modes: parsed.modes,
            activatesMode: parsed.activatesMode, isDisabled: true)
    }

    /// A later line of a disabled binding as it was before `disable`, or nil
    /// when the line is not one.
    static func uncommented(_ line: String) -> String? {
        if line.hasPrefix("# ") { return String(line.dropFirst(2)) }
        return line.trimmingCharacters(in: .whitespaces) == "#" ? "" : nil
    }

    /// Whether a parsed binding names modifiers and a key skhd knows. Without
    /// the marker it also needs a modifier or a mode, as a key name on its
    /// own is more likely the start of a sentence.
    private static func isChord(_ binding: SkhdBinding, marked: Bool) -> Bool {
        let modifiers: Set<String> = [
            "fn", "cmd", "lcmd", "rcmd", "alt", "lalt", "ralt", "shift", "lshift", "rshift",
            "ctrl", "lctrl", "rctrl", "hyper", "meh"
        ]
        guard binding.modifiers.allSatisfy({ modifiers.contains($0.lowercased()) }) else {
            return false
        }
        if !marked, binding.modifiers.isEmpty, binding.modes.isEmpty { return false }
        let key = binding.key.lowercased()
        if SkhdKey.named[key] != nil || SkhdBinding.keyGlyphs[key] != nil { return true }
        if key.hasPrefix("0x"), UInt16(key.dropFirst(2), radix: 16) != nil { return true }
        return key.count == 1 && key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
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
    /// skhd's form is `[mode, … <] keysym [->] (: command | [ … ] | ; mode)`.
    /// The key spec never contains `:`, `[` or `;`, so the first of these ends
    /// it. Searching for `->` anywhere would match inside commands such as
    /// `echo "a -> b"` and discard part of them on rewrite.
    struct Split {
        enum Kind { case command, block, activation }

        /// Where the chord starts, after the indent and any `mode <` prefix,
        /// both of which are kept verbatim on rewrite.
        let keyStart: String.Index
        let keySpec: String
        /// The modes named before `<`; empty means skhd's default mode.
        let modes: [String]
        /// Index of the `:`, `[` or `;`, which is kept verbatim on rewrite.
        let rest: String.Index
        let kind: Kind
        let passthrough: Bool
    }

    static func split(_ line: String) -> Split? {
        guard let boundary = line.firstIndex(where: { $0 == ":" || $0 == "[" || $0 == ";" })
        else { return nil }
        let blank: (Character) -> Bool = { $0 == " " || $0 == "\t" }
        var keyStart = line.firstIndex { !blank($0) } ?? boundary
        var modes: [String] = []
        if let marker = line[keyStart..<boundary].firstIndex(of: "<") {
            modes = line[keyStart..<marker].split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !modes.isEmpty else { return nil }
            keyStart =
                line[line.index(after: marker)..<boundary].firstIndex { !blank($0) } ?? boundary
        }
        var head = line[keyStart..<boundary].trimmingCharacters(in: .whitespaces)
        let passthrough = head.hasSuffix("->")
        if passthrough { head = head.dropLast(2).trimmingCharacters(in: .whitespaces) }
        // `::` declares a mode and `.` starts an option; neither is a chord.
        guard !head.isEmpty, !head.hasPrefix(".") else { return nil }
        let kind: Split.Kind =
            switch line[boundary] {
            case "[": .block
            case ";": .activation
            default: .command
            }
        return Split(
            keyStart: keyStart, keySpec: head, modes: modes, rest: boundary, kind: kind,
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
        if split.kind == .block {
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
                section: section, passthrough: split.passthrough, appOverrides: overrides,
                modes: split.modes)
            return (binding, blockEnd)
        }

        // Mode switch: `<keyspec> ; mode` runs nothing and enters the mode.
        if split.kind == .activation {
            let target = line[line.index(after: split.rest)...]
                .split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
            guard let target else { return (nil, end) }
            let binding = SkhdBinding(
                id: start, endLine: end, source: Array(lines[start...end]),
                modifiers: modifiers, key: key, command: "",
                section: section, passthrough: split.passthrough, appOverrides: [],
                modes: split.modes, activatesMode: target)
            return (binding, end)
        }

        // Standard form. Commands routinely contain colons (osascript, URLs), so
        // only the first one separates the key spec from the command.
        let command = line[line.index(after: split.rest)...].trimmingCharacters(
            in: .whitespaces)
        guard !command.isEmpty else { return (nil, end) }
        let binding = SkhdBinding(
            id: start, endLine: end, source: Array(lines[start...end]),
            modifiers: modifiers, key: key, command: command,
            section: section, passthrough: split.passthrough, appOverrides: [],
            modes: split.modes)
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

// MARK: - Conflicts

extension SkhdConfig {
    /// Another binding using this chord in a mode `binding` works in, if there
    /// is one. Without `binding` the chord is checked in the default mode. The
    /// same chord can mean different things in different modes, and a mode
    /// switch occupies its chord like any other binding. A disabled binding
    /// occupies nothing.
    public static func conflict(
        in bindings: [SkhdBinding], modifiers: some Sequence<String>, key: String,
        excluding binding: SkhdBinding?
    ) -> SkhdBinding? {
        let key = SkhdKey.normalised(key)
        let modifiers = SkhdKey.normalised(modifiers: modifiers)
        let modes = binding?.activeModes ?? ["default"]
        return bindings.first {
            $0.id != binding?.id && !$0.isDisabled
                && !$0.activeModes.isDisjoint(with: modes)
                && SkhdKey.normalised($0.key) == key
                && SkhdKey.normalised(modifiers: $0.modifiers) == modifiers
        }
    }
}
