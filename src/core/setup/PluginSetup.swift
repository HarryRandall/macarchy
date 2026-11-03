import Foundation

/// Seeds editable plugin configuration once and puts Macarchy's bundled
/// commands first on zsh's PATH. App updates preserve local edits.
///
/// The shell files are the person's own, so they are never backed up and
/// restored whole: setup adds one line and uninstall takes that line out,
/// leaving everything written around it.
enum PluginSetup {
    static let pathLine =
        "export PATH=\"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS:$PATH\""

    static var neovimConfig: URL { Paths.appRoot.appending(path: "plugins/neovim/config") }

    private static var bundledNeovimConfig: URL? {
        guard let source = Paths.resources?.appending(path: "plugins/neovim/config"),
            FileManager.default.fileExists(atPath: source.path)
        else { return nil }
        return source
    }

    /// `.zshenv` always comes from the home folder; `.zshrc` comes from
    /// `ZDOTDIR`, which an app opened from Finder only learns by asking zsh.
    static func shellFiles() -> [URL] {
        [Paths.home.appending(path: ".zshenv"), zshDirectory().appending(path: ".zshrc")]
    }

    private static func zshDirectory() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if Paths.relocatesHome(in: environment) { return Paths.home }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "print -r -- ${ZDOTDIR:-$HOME}"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return Paths.home }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
            let path = String(bytes: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            path.hasPrefix("/")
        else { return Paths.home }
        return URL(fileURLWithPath: path)
    }

    private static func hasLine(_ text: String) -> Bool {
        text.components(separatedBy: "\n").contains(pathLine)
    }

    /// A file setup may write: inside the home once links are followed, so a
    /// read-only store such as `/nix/store` is left alone.
    private static func writable(_ file: URL) -> URL? {
        let resolved = file.resolvingSymlinksInPath()
        let home = Paths.home.resolvingSymlinksInPath().path
        guard resolved.path.hasPrefix(home + "/") else { return nil }
        return resolved
    }

    static func plan() -> [Setup.Change] {
        var changes: [Setup.Change] = []
        if bundledNeovimConfig != nil, !FileManager.default.fileExists(atPath: neovimConfig.path) {
            changes.append(
                Setup.Change(
                    path: neovimConfig, action: .create,
                    detail: "Neovim configuration for Macarchy's nvim; later setups keep your edits"
                ))
        }
        for file in shellFiles() {
            let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            guard !hasLine(text) else { continue }
            changes.append(
                Setup.Change(
                    path: file, action: .include,
                    detail: writable(file) == nil
                        ? "Outside your home folder, so setup will say which line to add"
                        : "Adds one line that puts Macarchy's commands, its nvim among them, "
                            + "first on PATH"))
        }
        return changes
    }

    /// Nothing here stops setup: a file that cannot be written becomes a
    /// line in the report saying what to do by hand.
    static func install() -> [String] {
        var report: [String] = []
        let fm = FileManager.default
        if let source = bundledNeovimConfig, !fm.fileExists(atPath: neovimConfig.path) {
            do {
                try fm.createDirectory(
                    at: neovimConfig.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: neovimConfig)
                report.append("Installed Neovim configuration in \(Paths.display(neovimConfig))")
            } catch {
                report.append(
                    "Could not install Neovim configuration in \(Paths.display(neovimConfig)): "
                        + error.localizedDescription)
            }
        }
        for file in shellFiles() {
            do {
                if try addLine(to: file) {
                    report.append("Added Macarchy's bundled commands to \(Paths.display(file))")
                }
            } catch {
                report.append(
                    "Could not add Macarchy's commands to \(Paths.display(file)) "
                        + "(\(error.localizedDescription)). Add this line yourself: \(pathLine)")
            }
        }
        return report
    }

    private static func addLine(to file: URL) throws -> Bool {
        let fm = FileManager.default
        guard let target = writable(file) else {
            throw ConfigurationError("it is outside your home folder")
        }
        let current: String
        if fm.fileExists(atPath: target.path) {
            guard let text = try? String(contentsOf: target, encoding: .utf8) else {
                throw ConfigurationError("it is not UTF-8 text")
            }
            current = text
        } else {
            current = ""
        }
        guard !hasLine(current) else { return false }
        let permissions = try? fm.attributesOfItem(atPath: target.path)[.posixPermissions]
        let separator = current.isEmpty || current.hasSuffix("\n") ? "" : "\n"
        try fm.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (current + separator + pathLine + "\n").write(
            to: target, atomically: true, encoding: .utf8)
        if let permissions {
            try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path)
        }
        return true
    }

    /// Takes setup's line back out. A file left with nothing else in it was
    /// setup's own and is removed; a link to it is left as it is.
    static func uninstall(into report: inout [String]) throws {
        let fm = FileManager.default
        for file in shellFiles() {
            guard let target = writable(file),
                let text = try? String(contentsOf: target, encoding: .utf8), hasLine(text)
            else { continue }
            let kept = text.components(separatedBy: "\n").filter { $0 != pathLine }
                .joined(separator: "\n")
            let isLink = (try? fm.destinationOfSymbolicLink(atPath: file.path)) != nil
            if kept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isLink {
                try fm.removeItem(at: target)
                report.append("Removed \(Paths.display(file))")
            } else {
                let permissions = try? fm.attributesOfItem(atPath: target.path)[.posixPermissions]
                try kept.write(to: target, atomically: true, encoding: .utf8)
                if let permissions {
                    try fm.setAttributes(
                        [.posixPermissions: permissions], ofItemAtPath: target.path)
                }
                report.append("Removed Macarchy's commands from \(Paths.display(file))")
            }
        }
    }
}
