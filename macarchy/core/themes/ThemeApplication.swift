import Foundation

/// Both app and CLI enter here. The wallpaper helper and item plugin logic remain external.
public struct ThemeApplication: Sendable {
    public let integrations: Integrations
    public init(integrations: Integrations = Integrations()) { self.integrations = integrations }

    public func apply(name: String) async -> CommandResult {
        do {
            return try await OperationLock.run {
                var selected = name
                if name == "next" || name == "prev" {
                    let names = try FileManager.default.contentsOfDirectory(
                        at: Paths.themesDirectory, includingPropertiesForKeys: nil
                    )
                    .filter { Theme.load(from: $0) != nil }.map(\.lastPathComponent).sorted()
                    guard !names.isEmpty else { throw ConfigurationError("No themes installed") }
                    let current = try SettingsStore().read().currentTheme
                    if let index = names.firstIndex(where: { $0 == current }) {
                        selected =
                            names[(index + (name == "next" ? 1 : names.count - 1)) % names.count]
                    } else {
                        selected = name == "next" ? names[0] : names[names.count - 1]
                    }
                }
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

    // Keep the ordered desktop transaction together so partial failures are traceable.
    // swiftlint:disable:next function_body_length
    private func applyLocked(name: String) async -> CommandResult {
        do {
            guard name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_-]*$", options: .regularExpression) != nil
            else {
                throw ConfigurationError("Invalid theme name")
            }
            let directory = Paths.themesDirectory.appending(path: name)
            let theme = try Theme.read(from: directory)
            guard theme.name == name else {
                throw ConfigurationError("Theme folder and manifest name disagree")
            }
            let paletteURL = directory.appending(path: theme.apps.ghosttyConfig ?? "ghostty.conf")
                .resolvingSymlinksInPath()
            guard paletteURL.path.hasPrefix(directory.resolvingSymlinksInPath().path + "/") else {
                throw ConfigurationError("Palette must stay inside the theme")
            }
            let palette = try String(contentsOf: paletteURL, encoding: .utf8)
            let outputs = ThemeOutputs(theme: theme, ghostty: palette)
            let settings = try SettingsStore().read()
            let wallpaperURL = (settings.wallpapers[name] ?? theme.wallpaper).map {
                directory.appending(path: $0).resolvingSymlinksInPath()
            }
            if let wallpaperURL {
                guard wallpaperURL.path.hasPrefix(directory.resolvingSymlinksInPath().path + "/"),
                    FileManager.default.fileExists(atPath: wallpaperURL.path)
                else {
                    throw ConfigurationError("Wallpaper is missing or outside the theme")
                }
            }
            let fm = FileManager.default
            let home = Paths.home
            func write(_ text: String, to url: URL) throws {
                guard (try? String(contentsOf: url, encoding: .utf8)) != text else { return }
                try fm.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try text.write(to: url, atomically: true, encoding: .utf8)
            }
            let ghosttyURL = home.appending(path: ".config/ghostty/config")
            let oldGhostty = try String(contentsOf: ghosttyURL, encoding: .utf8)
            let btopURL = home.appending(path: ".config/btop/btop.conf")
            let shellURL = Paths.themesDirectory.appending(path: ".shell-env")
            let themeFile = home.appending(path: ".config/sketchybar/theme.sh")
            try SnapshotStore().capture(
                [
                    ghosttyURL, btopURL, shellURL, themeFile,
                    directory.appending(path: "theme.env"),
                    Paths.themesDirectory.appending(path: ".nvim-colorscheme"),
                    Paths.themesDirectory.appending(path: ".current"),
                    home.appending(path: ".config/btop/themes/active-theme.theme")
                ], reason: "apply theme \(name)")
            try write(
                GhosttyConfig.transform(config: oldGhostty, themeConf: palette, themeName: name),
                to: ghosttyURL)
            try write(outputs.shell, to: shellURL)
            // Compatibility outputs for installed shell plugins and editor hooks, not settings sources.
            try write(theme.envRepresentation(), to: directory.appending(path: "theme.env"))
            try write(
                outputs.nvim + "\n", to: Paths.themesDirectory.appending(path: ".nvim-colorscheme"))
            try write(
                "#!/usr/bin/env bash\nACCENT_COLOR=\"\(outputs.barAccent)\"\nTEXT_COLOR=\"\(outputs.barText)\"\nBAR_COLOR=\"\(outputs.barBackground)\"\n",
                to: themeFile)
            if fm.fileExists(atPath: btopURL.path) {
                try write(
                    outputs.btop, to: home.appending(path: ".config/btop/themes/active-theme.theme")
                )
                let config = try String(contentsOf: btopURL, encoding: .utf8)
                try write(
                    config.replacingOccurrences(
                        of: "(?m)^color_theme = .*", with: "color_theme = \"active-theme\"",
                        options: .regularExpression), to: btopURL)
            }
            let borders = await integrations.borders(
                BorderCommand.arguments(values: settings.legacyValues, theme: theme))
            guard borders.ok else { return borders }
            let recolour = await integrations.execute(
                home.appending(path: ".config/sketchybar/recolor.sh").path, [])
            guard recolour.ok else { return recolour }
            if let failure = await updateAppearance(theme) { return failure }
            if let image = wallpaperURL {
                let result = await integrations.execute(
                    home.appending(path: ".local/bin/set-wallpaper").path, [image.path])
                guard result.ok else { return result }
            }
            await refreshApplications()
            try SettingsStore().update { $0.currentTheme = name }
            try write(name + "\n", to: Paths.themesDirectory.appending(path: ".current"))
            return CommandResult(command: "theme \(name)", status: 0, stdout: "Applied \(name)")
        } catch {
            return CommandResult(
                command: "theme \(name)", status: 1, stderr: error.localizedDescription)
        }
    }
}
