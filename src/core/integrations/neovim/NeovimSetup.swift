import Foundation

/// Takes out the zsh PATH line an earlier setup added, which put the bundled
/// `nvim` launcher first.
///
/// The shell files are the person's own, so they are never backed up and
/// restored whole: uninstall takes that one line out, leaving everything
/// written around it.
///
/// Neovim's files stay in `plugins/neovim`, in Application Support and in the
/// app bundle, where earlier versions put them.
enum NeovimSetup {
    static let pathLine =
        "export PATH=\"$HOME/Library/Application Support/Macarchy/Macarchy.app/Contents/MacOS:$PATH\""

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
