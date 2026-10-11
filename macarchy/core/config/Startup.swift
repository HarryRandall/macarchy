import Foundation

public enum Startup {
    public static func apply(
        _ name: String, integrations: Integrations = Integrations()
    ) async throws {
        let settings = try SettingsStore().read()
        let values = settings.flatValues
        func require(_ result: CommandResult) throws {
            guard result.ok else {
                throw ConfigurationError(result.command + ": " + result.summary)
            }
        }
        switch name {
        case "yabai":
            for setting in StartupConfiguration.yabaiKeys {
                try require(
                    await integrations.yabaiWrite(
                        setting.key, value: values[setting.env] ?? setting.fallback))
            }
            for signal in signals {
                try require(await integrations.execute(Paths.yabai, signal))
            }
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [],
                integrations: integrations)
        case "sketchybar":
            if settings.bundledBar ?? true {
                try require(await bundledBar(integrations: integrations))
            }
            let arguments = StartupConfiguration.sketchybarKeys.map {
                "\($0.key)=\(values[$0.env] ?? $0.fallback)"
            }
            try require(await integrations.sketchybar(["--bar"] + arguments))
            for (name, visible) in settings.itemVisibility.sorted(by: { $0.key < $1.key }) {
                try require(
                    await integrations.sketchybar([
                        "--set", name, "drawing=\(visible ? "on" : "off")"
                    ]))
            }
            for (name, label) in settings.itemLabels.sorted(by: { $0.key < $1.key }) {
                try require(await integrations.sketchybar(["--set", name, "label=\(label)"]))
            }
            for pair in zip(settings.itemOrder, settings.itemOrder.dropFirst()) {
                try require(await integrations.sketchybar(["--move", pair.1, "after", pair.0]))
            }
            if let configuration = try BarConfigurationStore().load() {
                try await BarCommands.replay(configuration, integrations: integrations)
            }
        case "borders":
            let theme = settings.currentTheme.flatMap {
                Theme.load(from: Paths.themesDirectory.appending(path: $0))
            }
            try require(
                await integrations.borders(BorderCommand.arguments(values: values, theme: theme)))
        default: throw ConfigurationError("Unknown integration: \(name)")
        }
    }

    /// yabai signals Macarchy relies on. Labels make re-adding them replace
    /// the previous registration instead of stacking duplicates.
    static var signals: [[String]] {
        let cli = Shell.quote(Paths.appLink.appending(path: "Contents/MacOS/macarchy").path)
        let yabai = Shell.quote(Paths.yabai)
        let refocus =
            "\(yabai) -m query --windows --window >/dev/null 2>&1"
            + " || \(yabai) -m window --focus first >/dev/null 2>&1"
        // After Mission Control, yabai can still believe a window is focused
        // while macOS has handed focus elsewhere and no border is drawn, so
        // focus is re-asserted rather than only filled in. yabai also reports
        // the final Space a moment after the animation, so the bar looks again.
        let reassert =
            "id=$(\(yabai) -m query --windows --window 2>/dev/null"
            + " | /usr/bin/awk -F'[:,]' '/\"id\"/ { print $2; exit }');"
            + " if [ -n \"$id\" ]; then \(yabai) -m window --focus \"$id\" >/dev/null 2>&1;"
            + " else \(yabai) -m window --focus first >/dev/null 2>&1; fi"
        let missionControl =
            "sleep 0.25; \(reassert); \(Shell.quote(Paths.sketchybar))"
            + " --trigger macarchy_spaces_changed >/dev/null 2>&1"
        return [
            ("macarchy_mission_control_exit", "mission_control_exit", missionControl),
            ("macarchy_refocus_space", "space_changed", refocus),
            ("macarchy_window_created", "window_created", "\(cli) rules window-created"),
            ("macarchy_window_deminimized", "window_deminimized", "\(cli) rules window-created"),
            ("macarchy_refocus_destroyed", "window_destroyed", refocus),
            ("macarchy_refocus_terminated", "application_terminated", refocus)
        ].map { label, event, action in
            ["-m", "signal", "--add", "label=\(label)", "event=\(event)", "action=\(action)"]
        }
    }

    /// Builds the bar shipped with the app. The scripts are addressed through
    /// the app link so the items keep working when the app is updated in place.
    static func bundledBar(integrations: Integrations) async -> CommandResult {
        let stable = Paths.appLink.appending(path: "Contents/Resources/sketchybar")
        let directory =
            FileManager.default.fileExists(atPath: stable.path)
            ? stable : Paths.resources?.appending(path: "sketchybar")
        guard let directory else {
            return CommandResult(
                command: "menu bar", status: 1,
                stderr: "The bundled menu bar is missing. Reinstall Macarchy.")
        }
        return await integrations.execute("/bin/bash", [directory.appending(path: "bar.sh").path])
    }
}
