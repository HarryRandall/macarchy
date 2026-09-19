import Foundation

// The shell still consumes theme.env, so a manifest must regenerate an env file
// that is semantically identical to the one it replaced. If this drifts,
// bordersrc and theme-switch start seeing different values than the UI shows.

let themes = URL(fileURLWithPath: NSHomeDirectory())
    .appending(path: ".config/macarchy-settings/themes")

func parseEnv(_ url: URL) -> [String: String] {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
    var out: [String: String] = [:]
    for raw in text.split(separator: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
        var value = String(line[line.index(after: eq)...])
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        out[String(line[line.startIndex..<eq])] = value
    }
    return out
}

// BORDER_WIDTH moved to settings.env by design; it is not a theme concern.
let intentionallyDropped: Set<String> = ["BORDER_WIDTH"]

var checked = 0, failures = 0
let dirs = (try? FileManager.default.contentsOfDirectory(at: themes, includingPropertiesForKeys: nil)) ?? []

for dir in dirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
    guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
          let manifest = ThemeManifest.load(from: dir) else { continue }
    checked += 1

    let onDisk = parseEnv(dir.appending(path: "theme.env"))
    let regenerated = manifest.envValues()

    // Everything the env file holds must survive, except what we dropped.
    for (key, value) in onDisk where !intentionallyDropped.contains(key) {
        if regenerated[key] != value {
            print("  MISMATCH \(dir.lastPathComponent) \(key): env=\(value) manifest=\(regenerated[key] ?? "nil")")
            failures += 1
        }
    }
    // And the generated text must parse back to the same values.
    let reparsed = parseEnv(dir.appending(path: "theme.env"))
    for (key, value) in regenerated where reparsed[key] != nil && reparsed[key] != value {
        print("  UNSTABLE \(dir.lastPathComponent) \(key)")
        failures += 1
    }
}

print("themes checked:", checked, "(expected 8)")
print("mismatches:", failures, "(expected 0)")
