import Foundation

/// The person's own part of each startup file setup writes, and the setting
/// changes that come with it.
extension Setup {
    typealias SettingsEdit = ((inout SettingsDocument) throws -> Void) throws -> Void

    /// The person's part of sketchybarrc, the report lines that go with it,
    /// and whether SketchyBar starts from the launcher in their bar folder.
    struct BarRegion {
        var region: String?
        var lines: [String]
        var launcher: Bool
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

    /// The sketchybarrc region, and whether SketchyBar should start from the
    /// launcher in the person's bar folder (`StartupConfiguration.barLauncher`).
    /// An earlier version's region carries over and its `bundledBar` setting
    /// still says whose bar runs; only a missing one means Macarchy's. A
    /// hand-built bar kept with `keep` replaces Macarchy's. The region is nil
    /// once the file is Macarchy's, and the launcher then stays as it is.
    static func barRegion(
        existing: Existing, settings: SettingsStore, updateSettings: SettingsEdit
    ) async throws -> BarRegion {
        guard !isGenerated(StartupConfiguration.sketchybarrc.url) else {
            return BarRegion(region: nil, lines: [], launcher: StartupConfiguration.usesBarLauncher)
        }
        var lines: [String] = []
        if let source = sketchybarSource, isGenerated(source) {
            let region = try await carriedRegion(from: source, report: &lines)
            let bundled = try settings.read().bundledBar
            switch bundled {
            case nil: try updateSettings { $0.bundledBar = true }
            case false?: lines.append("Kept your menu bar")
            case true?: break
            }
            return BarRegion(
                region: region, lines: lines,
                launcher: bundled == false || region.contains("CONFIG_DIR"))
        }
        guard existing == .keep, let source = sketchybarSource, let text = adoptable(source)
        else {
            try updateSettings { $0.bundledBar = true }
            return BarRegion(region: "", lines: [], launcher: false)
        }
        let bar = StartupConfiguration.tidy(
            text.components(separatedBy: "\n").filter { !$0.hasPrefix("#!") })
        let kept = await pointingAtNewFolder(bar, in: source, report: &lines)
        try updateSettings { $0.bundledBar = false }
        lines.append("Kept your menu bar")
        return BarRegion(region: kept, lines: lines, launcher: true)
    }

    /// The plan's line for the launcher, when the first setup will write one.
    static func launcherChange(_ existing: Existing) -> Change? {
        guard !isGenerated(StartupConfiguration.sketchybarrc.url),
            let source = sketchybarSource
        else { return nil }
        let wanted =
            isGenerated(source)
            ? (try? SettingsStore().read().bundledBar) == false
                || mentionsConfigDirectory(source)
            : existing == .keep && adoptable(source) != nil
        guard wanted else { return nil }
        return Change(
            path: StartupConfiguration.barLauncher, action: .create,
            detail: "Starts your bar from its own folder, so its items find their plugins, "
                + "colours and icons as before. Uninstall removes it")
    }

    private static func mentionsConfigDirectory(_ source: URL) -> Bool {
        (try? String(contentsOf: source, encoding: .utf8))?.contains("CONFIG_DIR") == true
    }

    /// Writes or removes the launcher in the person's bar folder. It is
    /// backed up as absent first, so uninstall removes it.
    static func placeBarLauncher(_ wanted: Bool, backups: Backups) throws -> [String] {
        let launcher = StartupConfiguration.barLauncher
        let fm = FileManager.default
        guard wanted else {
            guard StartupConfiguration.usesBarLauncher else { return [] }
            try fm.removeItem(at: launcher)
            return ["Removed \(Paths.display(launcher))"]
        }
        let content = StartupConfiguration.barLauncherContent
        guard (try? String(contentsOf: launcher, encoding: .utf8)) != content else { return [] }
        if fm.fileExists(atPath: launcher.path), !StartupConfiguration.usesBarLauncher {
            throw ConfigurationError(
                "\(Paths.display(launcher)) exists and is not Macarchy's. Move it aside, then "
                    + "set up again.")
        }
        var lines = try backups.save([launcher]).map { "Backed up \(Paths.display($0))" }
        try fm.createDirectory(
            at: launcher.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: launcher, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcher.path)
        lines.append(
            "Wrote \(Paths.display(launcher)), so your bar's items find their files as before")
        return lines
    }
}
