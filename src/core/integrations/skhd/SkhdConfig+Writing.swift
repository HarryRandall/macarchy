import Foundation

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
    /// Only the chord is rewritten: a `mode <` prefix stays, so the shortcut
    /// keeps working in the same mode, and everything from the first `:`, `[`
    /// or `;` stays, because a command routinely contains colons and arrows.
    /// Returns `nil` when the line is not a binding, so a miscounted index
    /// cannot corrupt the file.
    public static func rebind(
        _ text: String, line index: Int, modifiers: [String], key: String
    ) -> String? {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index) else { return nil }

        let line = lines[index]
        guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("#"),
            let split = split(line)
        else { return nil }
        let spec = keySpec(modifiers: modifiers, key: key) + (split.passthrough ? " ->" : "")
        lines[index] = String(line[..<split.keyStart]) + spec + " " + String(line[split.rest...])
        return lines.joined(separator: "\n")
    }

    /// Rebinds `binding`, refusing if the file no longer holds it where it was read.
    ///
    /// Another editor may have inserted lines since the page loaded; trusting
    /// the stored line number alone would then rewrite a different shortcut.
    public static func rebind(
        _ text: String, binding: SkhdBinding, modifiers: [String], key: String
    ) -> String? {
        guard !binding.isDisabled, matches(text, binding) else { return nil }
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
        commentOut(&lines, index...logicalEnd(lines, from: index))
        return lines.joined(separator: "\n")
    }

    /// Comments out every line of `binding`, including a per-app block's body
    /// and closing bracket or a continued command's later lines, which would
    /// otherwise stay live or break parsing.
    public static func disable(_ text: String, binding: SkhdBinding) -> String? {
        guard !binding.isDisabled, matches(text, binding) else { return nil }
        var lines = text.components(separatedBy: "\n")
        commentOut(&lines, binding.id...binding.endLine)
        return lines.joined(separator: "\n")
    }

    /// The first line gains `disabledMarker` and the rest `# `. An empty line
    /// becomes `#`, so there is no trailing space for an editor to trim.
    private static func commentOut(_ lines: inout [String], _ range: ClosedRange<Int>) {
        for index in range {
            let line = lines[index]
            lines[index] =
                index == range.lowerBound ? disabledMarker + line : line.isEmpty ? "#" : "# " + line
        }
    }

    /// Undoes `disable`: removes the marker and the `# ` it wrote before each
    /// of the binding's lines, and nothing else, so the original bytes come
    /// back. A `#` left alone becomes the empty line it was.
    public static func enable(_ text: String, binding: SkhdBinding) -> String? {
        guard binding.isDisabled, matches(text, binding) else { return nil }
        var lines = text.components(separatedBy: "\n")
        for index in binding.id...binding.endLine {
            let line = lines[index]
            if index == binding.id {
                let prefix = line.hasPrefix(disabledMarker) ? disabledMarker : "# "
                guard line.hasPrefix(prefix) else { return nil }
                lines[index] = String(line.dropFirst(prefix.count))
            } else {
                guard let body = uncommented(line) else { return nil }
                lines[index] = body
            }
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
