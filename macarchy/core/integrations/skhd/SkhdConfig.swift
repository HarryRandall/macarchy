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

    private static func parseBinding(
        _ line: String, at lineIndex: Int, section: String?,
        lines: [String], cursor: inout Int
    ) -> SkhdBinding? {
        // App-specific form: `<keyspec> -> [` … `]`
        if let arrow = line.range(of: "->") {
            let keySpec = String(line[line.startIndex..<arrow.lowerBound])
            var overrides: [SkhdBinding.AppOverride] = []

            if line[arrow.upperBound...].trimmingCharacters(in: .whitespaces).hasPrefix("[") {
                var scan = cursor + 1
                while scan < lines.count {
                    let entry = lines[scan].trimmingCharacters(in: .whitespaces)
                    scan += 1
                    if entry.hasPrefix("]") { break }
                    guard let colon = entry.firstIndex(of: ":") else { continue }
                    let app = entry[entry.startIndex..<colon]
                        .trimmingCharacters(in: CharacterSet(charactersIn: " \"\t"))
                    let command = entry[entry.index(after: colon)...].trimmingCharacters(
                        in: .whitespaces)
                    if !app.isEmpty { overrides.append(.init(app: app, command: command)) }
                }
                cursor = scan - 1
            }

            let (modifiers, key) = splitKeySpec(keySpec)
            guard !key.isEmpty else { return nil }
            return SkhdBinding(
                id: lineIndex, modifiers: modifiers, key: key,
                command: overrides.first(where: { $0.app == "*" })?.command ?? "",
                section: section, passthrough: true, appOverrides: overrides)
        }

        // Standard form. Commands routinely contain colons (osascript, URLs), so
        // only the first one separates the key spec from the command.
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let keySpec = String(line[line.startIndex..<colon])
        let command = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return nil }

        let (modifiers, key) = splitKeySpec(keySpec)
        guard !key.isEmpty else { return nil }
        return SkhdBinding(
            id: lineIndex, modifiers: modifiers, key: key, command: command,
            section: section, passthrough: false, appOverrides: [])
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
