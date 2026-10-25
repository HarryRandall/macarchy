import Foundation

/// The person's own part of each startup file setup writes, and the setting
/// changes that come with it.
extension Setup {
    typealias SettingsEdit = ((inout SettingsDocument) throws -> Void) throws -> Void

    /// The person's part of sketchybarrc and the report lines that go with it.
    struct BarRegion {
        var region: String?
        var lines: [String]
    }

    /// The plan's line for a startup file an earlier version wrote.
    static func carriedChange(_ url: URL, source: URL?) -> Change? {
        guard let source, isGenerated(source) else { return nil }
        return Change(
            path: url, action: .adopt,
            detail: "Carries over the commands in the keep region of "
                + "\(Paths.display(source)), written by an earlier version")
    }

    /// The plan's line for bordersrc.
    static func bordersChange() -> Change {
        let url = StartupConfiguration.bordersrc.url
        if !isGenerated(url), let carried = carriedChange(url, source: bordersSource) {
            return carried
        }
        return Change(
            path: url,
            action: FileManager.default.fileExists(atPath: url.path) ? .replace : .create,
            detail: "Borders follow the theme and the Borders page")
    }

    /// The plan's line for the shortcuts, which are only ever seeded.
    static func shortcutsChange(_ existing: Existing) -> Change {
        let url = skhdrc
        if FileManager.default.fileExists(atPath: url.path) {
            return Change(path: url, action: .adopt, detail: "Already set up; left as it is")
        }
        if existing == .keep, let source = skhdSource, let text = adoptable(source) {
            let old = LegacyLayout.mentionsOldFolder(text)
            return Change(
                path: url, action: .adopt,
                detail: old
                    ? "Starts from your own shortcuts, pointing those that run Macarchy from "
                        + "\(Paths.display(Paths.legacyRoot)) at its new folder"
                    : "Starts from your own shortcuts")
        }
        return Change(path: url, action: .create, detail: "Installs Macarchy's default shortcuts")
    }

    /// The yabairc region: carried from an earlier version, adopted from the
    /// person's own with `keep` (standalone settings move into JSON), or
    /// empty. Nil once the file is Macarchy's, so its own region stays.
    static func yabaiRegion(
        existing: Existing, updateSettings: SettingsEdit
    ) async throws
        -> (region: String?, lines: [String])
    {
        guard !isGenerated(StartupConfiguration.yabairc.url) else { return (nil, []) }
        var lines: [String] = []
        if let source = yabaiSource, isGenerated(source) {
            return (try await carriedRegion(from: source, report: &lines), lines)
        }
        guard existing == .keep, let source = yabaiSource, let text = adoptable(source) else {
            return ("", [])
        }
        let adopted = StartupConfiguration.adoptYabai(text)
        try updateSettings { $0.mergeFlat(adopted.values) }
        let kept = await pointingAtNewFolder(adopted.kept, in: source, report: &lines)
        lines.append("Moved \(adopted.values.count) yabai settings into Macarchy")
        return (kept, lines)
    }

    /// The bordersrc region: carried from an earlier version's file, or nil
    /// to keep the region already in Macarchy's. borders is configured from
    /// settings, so nothing else is adopted.
    static func bordersRegion() async throws -> (region: String?, lines: [String]) {
        guard !isGenerated(StartupConfiguration.bordersrc.url), let source = bordersSource,
            isGenerated(source)
        else { return (nil, []) }
        var lines: [String] = []
        return (try await carriedRegion(from: source, report: &lines), lines)
    }

    /// The launchers that installed daemons start from (`StartLauncher`).
    static var launchers: [StartLauncher] {
        StartLauncher.all.filter { Paths.isInstalled($0.daemon.executableName) }
    }

    /// Writes each installed daemon's launcher before its agent, which names it.
    static func placeLaunchers(backups: Backups) throws -> [String] {
        try launchers.flatMap { try $0.place(backups: backups) }
    }
}
