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
    /// Each theme is copied into a staging folder and moved into place, so a
    /// failed copy leaves no partial theme that later runs would skip. The
    /// line lists the themes installed before any failure.
    static func installThemes(report: inout [String]) throws {
        let fm = FileManager.default
        guard let source = Paths.resources?.appending(path: "themes") else {
            throw ConfigurationError("Bundled themes are missing. Reinstall Macarchy.")
        }
        var installed: [String] = []
        defer {
            if !installed.isEmpty {
                report.append("Installed themes: \(installed.joined(separator: ", "))")
            }
        }
        for theme in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        where Theme.load(from: theme) != nil {
            let destination = Paths.themesDirectory.appending(path: theme.lastPathComponent)
            guard !fm.fileExists(atPath: destination.path) else { continue }
            let staging = Paths.themesDirectory.appending(path: ".install-\(UUID())")
            defer { try? fm.removeItem(at: staging) }
            try fm.copyItem(at: theme, to: staging)
            try fm.moveItem(at: staging, to: destination)
            installed.append(theme.lastPathComponent)
        }
    }

    /// skhd's file is only seeded, from the person's own shortcuts or the
    /// defaults; after that it is theirs, edited on the Shortcuts page.
    /// Shortcuts that ran the command from the old folder, as earlier
    /// defaults did, are pointed at the new one.
    static func seedShortcuts(existing: Existing, report: inout [String]) throws {
        let shortcuts = skhdrc
        guard !FileManager.default.fileExists(atPath: shortcuts.path) else { return }
        if existing == .keep, let source = skhdSource, let text = adoptable(source) {
            try FileManager.default.createDirectory(
                at: shortcuts.deletingLastPathComponent(), withIntermediateDirectories: true)
            var lines: [String] = []
            let carried = pointingAtNewFolder(text, in: source, report: &lines)
            try carried.write(to: shortcuts, atomically: true, encoding: .utf8)
            report.append("Copied your shortcuts from \(Paths.display(source))")
            report += lines
        } else {
            try installDefaultShortcuts(to: shortcuts)
            report.append("Installed default shortcuts")
        }
    }

    /// Writes the default shortcuts. They run tools by name, since
    /// Macarchy's skhd agent gives them a PATH that finds yabai and the CLI.
    public static func installDefaultShortcuts(to url: URL = skhdrc) throws {
        guard let source = Paths.resources?.appending(path: "skhd/skhdrc") else {
            throw ConfigurationError("Default shortcuts are missing. Reinstall Macarchy.")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = try String(contentsOf: source, encoding: .utf8)
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
