import Foundation

/// What `macarchy widget list` and `macarchy widget check` print.
public enum WidgetReport {
    /// One line per widget, then the folders that could not be used and why.
    public static func list(_ catalogue: WidgetCatalogue = WidgetCatalogue()) -> [String] {
        let snapshot = catalogue.read()
        let width = (snapshot.entries.map(\.id.count).max() ?? 0) + 2
        let nameWidth = (snapshot.entries.map(\.manifest.name.count).max() ?? 0) + 2
        var lines = snapshot.entries.map { entry in
            var notes = [entry.origin == .builtIn ? "built-in" : "yours"]
            if entry.manifest.isScripted { notes.append("runs a script") }
            return entry.id.padding(toLength: width, withPad: " ", startingAt: 0)
                + entry.manifest.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
                + notes.joined(separator: ", ")
        }
        if snapshot.entries.isEmpty { lines.append("No widgets found.") }
        if !snapshot.problems.isEmpty {
            lines.append("")
            lines.append("Not loaded:")
            for folder in snapshot.problems.keys.sorted() {
                for problem in snapshot.problems[folder] ?? [] {
                    lines.append("  \(folder)/\(problem)")
                }
            }
        }
        return lines
    }

    /// Checks one widget, named by id or by a path to its folder.
    public static func check(
        _ target: String, catalogue: WidgetCatalogue = WidgetCatalogue(),
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> (lines: [String], ok: Bool) {
        guard let folder = folder(for: target, catalogue: catalogue, in: workingDirectory) else {
            return (
                ["There is no widget called \(target). See them with: macarchy widget list"], false
            )
        }
        let check = WidgetManifest.check(folder: folder)
        let name = folder.lastPathComponent
        guard check.ok, let manifest = check.manifest else {
            return (check.problems.map { "\(name)/\($0)" }, false)
        }
        let script = manifest.isScripted ? ", and runs a script as you" : ""
        return (["\(name): \(manifest.name) \(manifest.version) is ready\(script)."], true)
    }

    private static func folder(
        for target: String, catalogue: WidgetCatalogue, in directory: URL
    ) -> URL? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        let path =
            target.hasPrefix("/") ? URL(fileURLWithPath: target) : directory.appending(path: target)
        if target.contains("/") || target == "." {
            return fm.fileExists(atPath: path.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
                ? path.standardizedFileURL : nil
        }
        if let entry = catalogue.read().entry(target) { return entry.directory }
        for root in [catalogue.user, catalogue.builtIn].compactMap({ $0 }) {
            let candidate = root.appending(path: target)
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                isDirectory.boolValue
            {
                return candidate
            }
        }
        return nil
    }
}
