import Foundation

extension Setup {
    static let defaultTheme = "midnight"

    /// Points the app link at `app`, replacing a stale link but never a real file.
    public static func link(_ app: URL) throws {
        let fm = FileManager.default
        let target = app.resolvingSymlinksInPath().path
        if let existing = try? fm.destinationOfSymbolicLink(atPath: Paths.appLink.path) {
            if existing == target { return }
            try fm.removeItem(at: Paths.appLink)
        } else if fm.fileExists(atPath: Paths.appLink.path) {
            throw ConfigurationError("\(Paths.display(Paths.appLink)) exists and is not a link")
        }
        try fm.createSymbolicLink(atPath: Paths.appLink.path, withDestinationPath: target)
    }

    /// Copies bundled themes that are not installed yet. Installed themes,
    /// including edited copies of bundled ones, are never overwritten.
    static func installThemes() throws -> [String] {
        let fm = FileManager.default
        guard let source = Paths.resources?.appending(path: "themes") else {
            throw ConfigurationError("Bundled themes are missing. Reinstall Macarchy.")
        }
        var installed: [String] = []
        for theme in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        where Theme.load(from: theme) != nil {
            let destination = Paths.themesDirectory.appending(path: theme.lastPathComponent)
            guard !fm.fileExists(atPath: destination.path) else { continue }
            try fm.copyItem(at: theme, to: destination)
            installed.append(theme.lastPathComponent)
        }
        return installed.isEmpty ? [] : ["Installed themes: \(installed.joined(separator: ", "))"]
    }

    /// Writes the default shortcuts with yabai's full path. skhd keeps the PATH
    /// it was registered with, which from Finder does not include Homebrew.
    public static func installDefaultShortcuts(to url: URL = skhdrc) throws {
        guard let source = Paths.resources?.appending(path: "skhd/skhdrc") else {
            throw ConfigurationError("Default shortcuts are missing. Reinstall Macarchy.")
        }
        let template = try String(contentsOf: source, encoding: .utf8)
        let text = template.replacingOccurrences(
            of: " yabai -m ", with: " \(Shell.quote(Paths.yabai)) -m ")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Stops setup when a startup file could not be written, and reports
    /// edits made outside its keep region that the new file replaced.
    static func check(_ outcome: GeneratedFile.Outcome, _ name: String) throws -> [String] {
        switch outcome {
        case .failed(let message): throw ConfigurationError(message)
        case .writtenOverDrift(let snapshot):
            let saved = snapshot.map { "snapshot \($0)" } ?? "a snapshot"
            return [
                "Replaced edits to \(name) made outside its keep region; "
                    + "your edited copy is saved as \(saved)"
            ]
        case .unchanged, .written: return []
        }
    }
}
