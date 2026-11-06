import Foundation

/// The widget bar is the only bar. Earlier versions ran either Macarchy's
/// bundled bar or a person's own sketchybarrc and saved which under
/// `bundledBar`. Setup moves either onto widgets once, after a snapshot,
/// and then removes the key; the app opens setup until it has.
extension SettingsDocument {
    /// Whose bar an earlier version ran, until setup moves it onto widgets:
    /// true for Macarchy's bundled bar, false for the person's own, and nil
    /// once moved or on a new install. The key stays among the unknown keys
    /// meanwhile, so every other settings write carries it.
    public var barBeforeWidgets: Bool? {
        if case .bool(let bundled)? = unknownKeys[Setup.earlierBarKey] { return bundled }
        return nil
    }
}

extension Setup {
    static let earlierBarKey = "bundledBar"

    /// Whether setup still has to move an earlier bar onto widgets. Settings
    /// that cannot be read count as no: Doctor and setup report those. A
    /// setup that left SketchyBar out never moves it.
    public static var barNeedsMoving: Bool {
        guard let settings = try? SettingsStore().read(), settings.barBeforeWidgets != nil
        else { return false }
        return settings.tools.map { $0.contains(Daemon.sketchybar.rawValue) } ?? true
    }

    /// Where a person's own bar's commands are kept once the bar is widgets.
    static var ownBarArchive: URL {
        Paths.configDirectory.appending(path: "own-bar-before-widgets.sh")
    }

    /// The plan's lines for the bar: its startup file, and the move onto
    /// widgets when an earlier version set it up.
    static func barChanges() -> [Change] {
        let url = StartupConfiguration.sketchybarrc.url
        let earlier = (try? SettingsStore().read())?.barBeforeWidgets
        let archive = Paths.display(ownBarArchive)
        let change: Change
        if isGenerated(url) {
            change = Change(
                path: url, action: .replace,
                detail: earlier == false
                    ? "Regenerated for the widget bar. Your own bar's commands move to \(archive) "
                        + "and stop running"
                    : "Regenerated, keeping your region")
        } else if let source = sketchybarSource, isGenerated(source) {
            change = Change(
                path: url, action: .adopt,
                detail: earlier == false
                    ? "Sets up the widget bar. Your own bar's commands in the keep region of "
                        + "\(Paths.display(source)) are kept in \(archive) and stop running"
                    : "Carries over the commands in the keep region of "
                        + "\(Paths.display(source)), written by an earlier version")
        } else {
            let own = sketchybarSource.flatMap { adoptable($0) == nil ? nil : $0 }
            change = Change(
                path: url,
                action: FileManager.default.fileExists(atPath: url.path) ? .replace : .create,
                detail: "Sets up the menu bar with Macarchy's widgets"
                    + (own.map { "; \(Paths.display($0)) is left as it is, unused" } ?? ""))
        }
        guard earlier != nil else { return [change] }
        return [
            change,
            Change(
                path: Paths.settings, action: .replace,
                detail: "Moves the menu bar onto widgets after a snapshot: its items become "
                    + "built-in widgets, command items become scripted widgets in "
                    + "\(Paths.display(Paths.widgetsDirectory)) and hidden items are removed")
        ]
    }

    /// The sketchybarrc region setup writes, nil to keep the one there, and
    /// the bar itself: the widget layout on a new install, or an earlier
    /// bar moved onto widgets.
    static func barRegion(
        settings: SettingsStore, updateSettings: SettingsEdit
    ) async throws -> BarRegion {
        let file = StartupConfiguration.sketchybarrc
        let document = try settings.read()
        let earlier = document.barBeforeWidgets
        // An earlier version's file where SketchyBar looks by default, until
        // Macarchy's own file holds its region.
        let earlierFile = sketchybarSource.flatMap { isGenerated($0) ? $0 : nil }
        let carried = isGenerated(file.url) ? nil : earlierFile
        var lines: [String] = []
        if earlier != nil {
            let saved = try SnapshotStore().capture(
                [settings.url, file.url], reason: "before moving the menu bar onto widgets")
            if let saved { lines.append("Saved the menu bar as it was in snapshot \(saved.id)") }
        }
        var region: String?
        var archive: URL?
        if earlier == false {
            // A person's own bar built every item in its region, starting by
            // removing every item, widgets included, so it no longer runs.
            let text =
                try carried.map(regions(of:))
                ?? file.preservedRegions()[StartupConfiguration.yoursRegion] ?? ""
            archive = try keepOwnBar(text, from: carried ?? file.url)
            if let archive {
                lines.append(
                    "Your own bar no longer runs, as the menu bar shows widgets now; its "
                        + "commands are kept in \(Paths.display(archive))")
            }
            region = ""
        } else if let carried {
            region = try await carriedRegion(from: carried, report: &lines)
        } else if !isGenerated(file.url) {
            region = ""
            if let own = sketchybarSource, adoptable(own) != nil {
                lines.append(
                    "Left \(Paths.display(own)) as it is: the menu bar shows Macarchy's widgets")
            }
        }
        if earlier != nil {
            lines += try moveOntoWidgets(document, archive: archive, updateSettings: updateSettings)
        } else if document.barConfiguration == nil {
            let bar = WidgetLook.current().normalised(.widgetDefault)
            try updateSettings { $0.setBar(bar) }
            lines.append("Set up the menu bar with Macarchy's widgets")
        }
        return BarRegion(region: region, lines: lines)
    }

    /// Moves an earlier bar onto widgets: writes the scripted widgets its
    /// command items become, saves the bar and drops the earlier key, and
    /// says what happened to every item.
    static func moveOntoWidgets(
        _ document: SettingsDocument, archive: URL?, updateSettings: SettingsEdit
    ) throws -> [String] {
        let move = WidgetMigration.moveBar(document.barConfiguration)
        try WidgetMigration.write(move.newWidgets)
        let bar = WidgetLook.current().normalised(move.configuration)
        try updateSettings { settings in
            settings.setBar(bar)
            settings.unknownKeys[earlierBarKey] = nil
        }
        func names(_ titles: [String]) -> String { titles.joined(separator: ", ") }
        var lines: [String] = []
        if document.barConfiguration == nil {
            lines.append("Moved the menu bar onto Macarchy's widgets")
        } else if move.replaced.isEmpty {
            lines.append("Moved the menu bar onto widgets")
        } else {
            lines.append(
                "Moved the menu bar onto widgets: \(names(move.replaced)) now "
                    + (move.replaced.count == 1
                        ? "shows a built-in widget" : "show built-in widgets"))
        }
        if move.startedFromDefault && document.barConfiguration != nil {
            lines.append("Nothing on the bar could become a widget, so it starts from the default")
        }
        if !move.newWidgets.isEmpty {
            lines.append(
                "Made scripted widgets from your command items in "
                    + "\(Paths.display(Paths.widgetsDirectory)): "
                    + names(move.newWidgets.map { "\($0.manifest.name) (\($0.manifest.id))" }))
        }
        if !move.removed.isEmpty {
            lines.append("Removed hidden items left from the earlier bar: \(names(move.removed))")
        }
        if !move.duplicates.isEmpty {
            lines.append(
                "Removed items whose widget was already on the bar: \(names(move.duplicates))")
        }
        if !move.unmatched.isEmpty {
            lines.append(
                "No widget replaces \(names(move.unmatched)), so "
                    + (move.unmatched.count == 1 ? "it is" : "they are") + " no longer on the bar"
                    + (archive.map { "; the commands that made them are in \(Paths.display($0))" }
                        ?? ""))
        }
        return lines
    }

    /// Writes a person's own bar beside Macarchy's startup files, where it
    /// no longer runs, with a note saying what it is. Nil when it was empty.
    static func keepOwnBar(_ text: String, from source: URL) throws -> URL? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.configDirectory, withIntermediateDirectories: true)
        var url = ownBarArchive
        var number = 2
        while fm.fileExists(atPath: url.path) {
            url = Paths.configDirectory.appending(path: "own-bar-before-widgets-\(number).sh")
            number += 1
        }
        let note = """
            # Your own menu bar, from the keep region of \(Paths.display(source)).
            # It relied on ~/.config/sketchybar: SketchyBar gave it that folder as
            # $CONFIG_DIR, where its plugins, colours and icons were.
            # Macarchy moved the bar onto widgets, so these commands no longer run.
            # Add widgets on the Menu Bar page, or copy a command back into the keep
            # region of sketchybarrc to run it after the widgets are set up.

            """
        try (note + text + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
