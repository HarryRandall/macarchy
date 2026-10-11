import Foundation

/// Applies a theme to whatever parts of the desktop are installed.
///
/// Both app and CLI enter here. Each integration is optional: a missing
/// Ghostty, bar or borders daemon is skipped and named in the result, so a
/// partial setup still themes everything it has.
public struct ThemeApplication: Sendable {
    public let integrations: Integrations
    public init(integrations: Integrations = Integrations()) { self.integrations = integrations }

    public func apply(name: String) async -> CommandResult {
        do {
            return try await OperationLock.run {
                let selected = try resolve(name)
                let result = await applyLocked(name: selected)
                if result.ok { return result }
                return CommandResult(
                    command: result.command, status: result.status, stdout: result.stdout,
                    stderr:
                        "Theme application did not finish; some changes may already have applied. "
                        + result.stderr)
            }
        } catch {
            return CommandResult(command: "theme", status: 1, stderr: error.localizedDescription)
        }
    }

    /// Maps `next` and `prev` onto an installed theme name.
    private func resolve(_ name: String) throws -> String {
        guard name == "next" || name == "prev" else { return name }
        let names = try FileManager.default.contentsOfDirectory(
            at: Paths.themesDirectory, includingPropertiesForKeys: nil
        )
        .filter { Theme.load(from: $0) != nil }.map(\.lastPathComponent).sorted()
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
    private func applyLocked(name: String) async -> CommandResult {
        do {
            guard name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression) != nil
            else { throw ConfigurationError("Invalid theme name") }
            let directory = Paths.themesDirectory.appending(path: name)
            let theme = try Theme.read(from: directory)
            guard theme.name == name else {
                throw ConfigurationError("Theme folder and manifest name disagree")
            }
            let palette = try theme.palette(in: directory)
            let outputs = ThemeOutputs(theme: theme, ghostty: palette ?? "")
            let settings = try SettingsStore().read()
            let wallpaper = try theme.wallpaperURL(
                in: directory, selected: settings.wallpapers[name])

            try SnapshotStore().capture(Self.outputs, reason: "apply theme \(name)")
            let generated = Paths.generatedDirectory
            try Self.write(palette ?? "", to: generated.appending(path: "ghostty.conf"))
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
                guard borders.ok else { return borders }
            } else {
                skipped.append("borders")
            }
            if Paths.isInstalled("sketchybar"), await integrations.state(of: .sketchybar).isRunning
            {
                let result = await recolourBar(bundled: settings.bundledBar ?? true)
                guard result.ok else { return result }
            } else {
                skipped.append("menu bar")
            }
            if let failure = await updateAppearance(theme) { return failure }
            if let wallpaper {
                _ = try await MainActor.run { try Wallpaper.set(wallpaper) }
            }
            await refreshApplications()
            try SettingsStore().update { $0.currentTheme = name }
            let note = skipped.isEmpty ? "" : " (not running: \(skipped.joined(separator: ", ")))"
            return CommandResult(
                command: "theme \(name)", status: 0, stdout: "Applied \(name)\(note)")
        } catch {
            return CommandResult(
                command: "theme \(name)", status: 1, stderr: error.localizedDescription)
        }
    }

    /// Macarchy's bar is recoloured in place. A person's own bar is told
    /// instead, through an event its items can subscribe to.
    private func recolourBar(bundled: Bool) async -> CommandResult {
        guard bundled else {
            // A bar that never registered the event is not an error.
            _ = await integrations.sketchybar(["--trigger", "macarchy_theme_changed"])
            return CommandResult(command: "menu bar", status: 0)
        }
        guard let script = Paths.resources?.appending(path: "sketchybar/recolor.sh") else {
            return CommandResult(
                command: "menu bar", status: 1, stderr: "The bundled menu bar is missing.")
        }
        return await integrations.execute(script.path, [])
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
