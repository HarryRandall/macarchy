import Foundation

/// The person's own part of each startup file setup writes, and the setting
/// changes that come with it.
extension Setup {
    typealias SettingsEdit = ((inout SettingsDocument) throws -> Void) throws -> Void

    /// The plan's line for a startup file an earlier version wrote.
    static func carriedChange(_ url: URL, source: URL?) -> Change? {
        guard let source, isGenerated(source) else { return nil }
        return Change(
            path: url, action: .adopt,
            detail: "Carries over the commands in the keep region of "
                + "\(Paths.display(source)), written by an earlier version")
    }

    /// The yabairc region: carried from an earlier version, adopted from the
    /// person's own with `keep` (standalone settings move into JSON), or
    /// empty. Nil once the file is Macarchy's, so its own region stays.
    static func yabaiRegion(
        existing: Existing, updateSettings: SettingsEdit
    ) throws
        -> (region: String?, lines: [String])
    {
        guard !isGenerated(StartupConfiguration.yabairc.url) else { return (nil, []) }
        var lines: [String] = []
        if let source = yabaiSource, isGenerated(source) {
            return (try carriedRegion(from: source, report: &lines), lines)
        }
        guard existing == .keep, let source = yabaiSource, let text = adoptable(source) else {
            return ("", [])
        }
        let adopted = StartupConfiguration.adoptYabai(text)
        try updateSettings { $0.mergeFlat(adopted.values) }
        let kept = pointingAtNewFolder(adopted.kept, in: source, report: &lines)
        lines.append("Moved \(adopted.values.count) yabai settings into Macarchy")
        return (kept, lines)
    }

    /// The sketchybarrc region. An earlier version's region carries over and
    /// its `bundledBar` setting still says whose bar runs; only a missing one
    /// means Macarchy's. A hand-built bar kept with `keep` replaces
    /// Macarchy's. Nil once the file is Macarchy's.
    static func barRegion(
        existing: Existing, settings: SettingsStore, updateSettings: SettingsEdit
    ) throws -> (region: String?, lines: [String]) {
        guard !isGenerated(StartupConfiguration.sketchybarrc.url) else { return (nil, []) }
        var lines: [String] = []
        if let source = sketchybarSource, isGenerated(source) {
            let region = try carriedRegion(from: source, report: &lines)
            let kept = keepingBarFolder(region, from: source, report: &lines)
            switch try settings.read().bundledBar {
            case nil: try updateSettings { $0.bundledBar = true }
            case false?: lines.append("Kept your menu bar")
            case true?: break
            }
            return (kept, lines)
        }
        guard existing == .keep, let source = sketchybarSource, let text = adoptable(source)
        else {
            try updateSettings { $0.bundledBar = true }
            return ("", [])
        }
        let bar = StartupConfiguration.tidy(
            text.components(separatedBy: "\n").filter { !$0.hasPrefix("#!") })
        let kept = keepingBarFolder(
            pointingAtNewFolder(bar, in: source, report: &lines), from: source, report: &lines)
        try updateSettings { $0.bundledBar = false }
        lines.append("Kept your menu bar")
        return (kept, lines)
    }
}
