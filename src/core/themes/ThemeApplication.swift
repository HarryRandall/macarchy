import Foundation

/// Applies a theme to whatever parts of the desktop are installed.
///
/// Both app and CLI enter here. Each integration is optional: a missing
/// Ghostty, bar or borders daemon is skipped and named in the result, so a
/// partial setup still themes everything it has.
public struct ThemeApplication: Sendable {
    public let integrations: Integrations
    public let effects: DesktopEffects
    public init(integrations: Integrations = Integrations(), effects: DesktopEffects = .current) {
        self.integrations = integrations
        self.effects = effects
    }

    /// Picking themes in quick succession applies the last one picked, even
    /// when an earlier pick is still waiting for the desktop. `next` and
    /// `prev` step from the theme current when they run, so each press counts.
    public func apply(name: String) async -> CommandResult {
        do {
            if name == "next" || name == "prev" {
                return try await OperationLock.run { await applyLocked(name: try resolve(name)) }
            }
            return try await OperationLock.runLatest(name, kind: "theme") {
                await applyLocked(name: try resolve($0))
            }
        } catch {
            return CommandResult(command: "theme", status: 1, stderr: error.localizedDescription)
        }
    }

    /// Maps `next` and `prev` onto an installed theme name. Only folders
    /// whose manifest carries the folder's name can be applied, so a copied
    /// folder that still names its original is stepped over, not landed on.
    private func resolve(_ name: String) throws -> String {
        guard name == "next" || name == "prev" else { return name }
        let names = try FileManager.default.contentsOfDirectory(
            at: Paths.themesDirectory, includingPropertiesForKeys: nil
        )
        .filter { Theme.load(from: $0)?.name == $0.lastPathComponent }
        .map(\.lastPathComponent).sorted()
        guard !names.isEmpty else { throw ConfigurationError("No themes installed") }
        let current = try SettingsStore().read().currentTheme
        guard let index = names.firstIndex(where: { $0 == current }) else {
            return name == "next" ? names[0] : names[names.count - 1]
        }
        return names[(index + (name == "next" ? 1 : names.count - 1)) % names.count]
    }

    /// Files the theme renders, in the order they are written.
    static var outputs: [URL] {
        ["ghostty.conf", "shell-env", "nvim-colorscheme", "bar-colours.sh"].map {
            Paths.generatedDirectory.appending(path: $0)
        }
    }

    // Keep the ordered desktop transaction together so partial failures are traceable.
    /// Chooses a theme's wallpaper. For the active theme the desktop is
    /// changed first and the choice saved only if that worked, so settings
    /// never point at a wallpaper the desktop does not show.
    public func chooseWallpaper(theme name: String, path: String) async -> CommandResult {
        do {
            return try await OperationLock.run {
                let directory = Paths.themesDirectory.appending(path: name)
                _ = try Theme.read(from: directory).wallpaperURL(in: directory, selected: path)
                if try SettingsStore().read().currentTheme == name {
                    let result = await applyLocked(name: name, wallpaper: path)
                    guard result.ok else { return result }
                }
                do { try SettingsStore().update { $0.wallpapers[name] = path } } catch {
                    return CommandResult(
                        command: "wallpaper \(name)", status: 1,
                        stderr:
                            "The wallpaper choice could not be saved; desktop changes may already have applied. "
                            + error.localizedDescription)
                }
                return CommandResult(command: "wallpaper \(name)", status: 0)
            }
        } catch {
            return CommandResult(
                command: "wallpaper \(name)", status: 1, stderr: error.localizedDescription)
        }
    }

    /// The theme transaction itself. Callers must hold the desktop lock.
    /// `wallpaper` overrides the saved choice for this application only.
    func applyLocked(name: String, wallpaper chosen: String? = nil) async -> CommandResult {
        var started = false
        func partial(_ result: CommandResult) -> CommandResult {
            CommandResult(
                command: result.command, status: result.status, stdout: result.stdout,
                stderr: "\(chosen == nil ? "Theme" : "Wallpaper") application did not finish; "
                    + "some changes may already have applied. " + result.stderr)
        }
        do {
            guard name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression) != nil
            else { throw ConfigurationError("Invalid theme name") }
            let directory = Paths.themesDirectory.appending(path: name)
            let theme = try Theme.read(from: directory)
            guard theme.name == name else {
                throw ConfigurationError(
                    "The theme folder \(name) contains the theme \(theme.name). Rename the "
                        + "folder or the name in its theme.json so they match.")
            }
            let palette = try theme.palette(in: directory)
            let outputs = ThemeOutputs(theme: theme, ghostty: palette ?? "")
            let settings = try SettingsStore().read()
            let wallpaper = try theme.wallpaperURL(
                in: directory, selected: chosen ?? settings.wallpapers[name])

            // Nothing has changed before this point, so earlier failures need
            // no warning about a half-applied theme.
            started = true
            try SnapshotStore().capture(Self.outputs, reason: "apply theme \(name)")
            let generated = Paths.generatedDirectory
            let ghostty = GhosttyConfig.colours(from: palette ?? "")
            try Self.write(ghostty.text, to: generated.appending(path: "ghostty.conf"))
            try Self.write(outputs.shell, to: generated.appending(path: "shell-env"))
            try Self.write(outputs.nvim + "\n", to: generated.appending(path: "nvim-colorscheme"))
            try Self.write(outputs.barColours, to: generated.appending(path: "bar-colours.sh"))

            var skipped: [String] = []
            // borders applies new arguments to a running instance. With none
            // running it would become the daemon itself and never return, so
            // a stopped service just picks the theme up when it starts.
            if Paths.isInstalled("borders"), await integrations.state(of: .borders).isRunning {
                let borders = await integrations.borders(
                    BorderCommand.arguments(values: settings.flatValues, theme: theme))
                guard borders.ok else { return partial(borders) }
            } else {
                skipped.append("borders")
            }
            if Paths.isInstalled("sketchybar"), await integrations.state(of: .sketchybar).isRunning
            {
                let result = await recolourBar(theme: theme, colours: BarLook.Colours(outputs))
                guard result.ok else { return partial(result) }
            } else {
                skipped.append("menu bar")
            }
            if let failure = await effects.setAppearance(theme.dark, integrations) {
                return partial(failure)
            }
            if let wallpaper { try await effects.setWallpaper(wallpaper) }
            await effects.refreshApplications(integrations)
            try SettingsStore().update { $0.currentTheme = name }
            return Self.applied(name, stopped: skipped, colours: ghostty.skipped)
        } catch {
            let failure = CommandResult(
                command: "theme \(name)", status: 1, stderr: error.localizedDescription)
            return started ? partial(failure) : failure
        }
    }

    /// Marks a skipped entry as a Ghostty colour the theme could not use,
    /// rather than a service that was not running.
    public static let ghosttyColourPrefix = "Ghostty colour "

    /// A finished theme, naming stopped services and any Ghostty colours
    /// left out, so a partial application is reported as one.
    static func applied(_ name: String, stopped: [String], colours: [String]) -> CommandResult {
        let notes = [
            stopped.isEmpty ? nil : "not running: \(stopped.joined(separator: ", "))",
            colours.isEmpty ? nil : "Ghostty colours left out: \(colours.joined(separator: ", "))"
        ].compactMap { $0 }
        let note = notes.isEmpty ? "" : " (\(notes.joined(separator: "; ")))"
        return CommandResult(
            command: "theme \(name)", status: 0, stdout: "Applied \(name)\(note)",
            skipped: stopped + colours.map { ghosttyColourPrefix + $0 })
    }

    /// Repaints the bar and its widgets in place: rebuilding would tear
    /// every item down and visibly paint the bar back in. The text of each
    /// widget goes to the theme's, then each widget's own colours go back
    /// on; the app's widget host picks the theme up when settings change.
    private func recolourBar(theme: Theme, colours: BarLook.Colours) async -> CommandResult {
        do {
            let look = WidgetLook.current(theme: theme)
            let configuration = look.normalised(try Startup.bar(try SettingsStore().read()))
            let existing = await BarCommands.items(integrations: integrations)
            let result = await integrations.sketchybar(
                BarLook.recolour(configuration, colours: colours, existing: existing))
            guard result.ok else { return result }
            try await BarCommands.replay(configuration, integrations: integrations, widgets: look)
            return CommandResult(command: "menu bar", status: 0)
        } catch {
            return CommandResult(command: "menu bar", status: 1, stderr: error.localizedDescription)
        }
    }

    static func write(_ text: String, to url: URL) throws {
        guard (try? String(contentsOf: url, encoding: .utf8)) != text else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

extension Theme {
    /// The theme's Ghostty palette, or nil when it ships none.
    public func palette(in directory: URL) throws -> String? {
        let url = try asset(apps.ghosttyConfig ?? "ghostty.conf", in: directory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            if apps.ghosttyConfig != nil {
                throw ConfigurationError("Theme palette \(apps.ghosttyConfig ?? "") is missing")
            }
            return nil
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The selected or default wallpaper. A theme without one leaves the desktop alone.
    public func wallpaperURL(in directory: URL, selected: String?) throws -> URL? {
        guard let path = selected ?? wallpaper else { return nil }
        let url = try asset(path, in: directory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigurationError("Wallpaper \(path) is missing from the theme")
        }
        return url
    }

    /// Resolves a theme-relative path, refusing anything that escapes the folder.
    public func asset(_ path: String, in directory: URL) throws -> URL {
        let root = directory.resolvingSymlinksInPath().path + "/"
        let url = directory.appending(path: path).resolvingSymlinksInPath()
        guard url.path.hasPrefix(root) else {
            throw ConfigurationError("Theme files must stay inside the theme folder")
        }
        return url
    }
}
