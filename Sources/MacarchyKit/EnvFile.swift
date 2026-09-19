import Foundation

/// Reader for the `KEY="value"` files the shell layer still consumes.
///
/// Shared by the settings store, the theme catalogue and the rc generators.
/// It lived on `ThemeCatalog` until moving the store into this module showed
/// that a settings file should not have to reach through a theme catalogue to
/// read a key=value pair.
public enum EnvFile {
    /// Parses `KEY=value` / `KEY="value"`, skipping comments and blank lines.
    public static func parse(_ url: URL) -> [String: String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(text: text)
    }

    public static func parse(text: String) -> [String: String] {
        var values: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"),
                let split = line.firstIndex(of: "=")
            else { continue }

            let key = String(line[line.startIndex..<split])
            var value = String(line[line.index(after: split)...])
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            values[key] = value
        }
        return values
    }

    /// Renders a dictionary back out, sorted so diffs stay stable.
    public static func render(_ values: [String: String], header: String) -> String {
        let body = values.sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\($0.value)\"" }
            .joined(separator: "\n")
        return header + body + "\n"
    }
}
