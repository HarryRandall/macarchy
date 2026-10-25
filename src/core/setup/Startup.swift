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
            // A person's own bar keeps its geometry unless they changed it
            // in Macarchy; Macarchy's bar gets the defaults.
            let bundled = settings.bundledBar ?? true
            let arguments = StartupConfiguration.sketchybarKeys.compactMap { key in
                (values[key.env] ?? (bundled ? key.fallback : nil)).map { "\(key.key)=\($0)" }
            }
            if !arguments.isEmpty {
                try require(await integrations.sketchybar(["--bar"] + arguments))
            }
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
                await fillWidgets(configuration, integrations: integrations)
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

    /// Where `recordRun` notes the daemon that last ran its startup file.
    static func runRecord(_ daemon: Daemon) -> URL {
        Paths.stateDirectory.appending(path: "startup/\(daemon.rawValue)")
    }

    /// Notes which copy of a daemon ran its startup file: the process launchd
    /// reports for the daemon's job while the file runs it. Doctor compares it
    /// with the copy running now, which is the only way to tell that a daemon
    /// started but never ran its file, as when yabai split a path at a space.
    /// Only the startup files call `macarchy startup`; the app applies
    /// settings directly. A record that cannot be written makes Doctor report
    /// the file as not run, the safer mistake, so failures are not reported.
    public static func recordRun(_ name: String, integrations: Integrations = Integrations()) async
    {
        guard let daemon = Daemon(rawValue: name),
            case .running(let pid) = await integrations.state(of: daemon)
        else { return }
        let url = runRecord(daemon)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "\(pid)\n".write(to: url, atomically: true, encoding: .utf8)
    }

    /// The process `recordRun` last noted for the daemon, if any.
    static func lastRun(_ daemon: Daemon) -> Int? {
        (try? String(contentsOf: runRecord(daemon), encoding: .utf8))
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Fills the widgets in now, so the bar is right before the app starts
    /// updating it, and stays right if the app is not running.
    static func fillWidgets(_ configuration: BarConfiguration, integrations: Integrations) async {
        guard configuration.components.contains(where: \.isWidget) else { return }
        let host = WidgetHost(integrations: integrations, runner: WidgetProviderRunner(timeout: 2))
        await host.reload()
        await host.refresh()
    }

    /// yabai signals Macarchy relies on. Labels make re-adding them replace
    /// the previous registration instead of stacking duplicates.
    static var signals: [[String]] {
        let cli = Shell.quote(Paths.appLink.appending(path: "Contents/MacOS/macarchy").path)
        let yabai = Shell.quote(Paths.yabai)
        let refocus =
            "\(yabai) -m query --windows --window >/dev/null 2>&1"
            + " || \(yabai) -m window --focus first >/dev/null 2>&1"
        let field = { (name: String) in
            "/usr/bin/awk -F'[:,]' '/\"\(name)\"/ { print $2; exit }'"
        }
        // After Mission Control, yabai can still believe a window is focused
        // while macOS has handed focus elsewhere and no border is drawn, so
        // focus is re-asserted rather than only filled in. Only a window on the
        // visible Space is re-asserted: after choosing another Space, yabai can
        // still report the previous Space's window, and focusing it would switch
        // back and undo the choice. The Space change handler below fills focus in
        // then. yabai also reports the final Space a moment after the animation,
        // so the bar looks again.
        let reassert =
            "space=$(\(yabai) -m query --spaces --space 2>/dev/null | \(field("index")));"
            + " window=$(\(yabai) -m query --windows --window 2>/dev/null);"
            + " id=$(printf '%s\\n' \"$window\" | \(field("id")));"
            + " if [ -z \"$id\" ]; then \(yabai) -m window --focus first >/dev/null 2>&1;"
            + " elif [ \"$(printf '%s\\n' \"$window\" | \(field("space")))\" = \"$space\" ]; then"
            + " \(yabai) -m window --focus \"$id\" >/dev/null 2>&1; fi"
        let missionControl =
            "sleep 0.25; \(reassert); \(Shell.quote(Paths.sketchybar))"
            + " --trigger macarchy_spaces_changed >/dev/null 2>&1"
        // Arriving on a Space, yabai first still reports the previous Space's
        // window as focused; a moment later macOS activates Finder or another
        // app with no window here, and no border is drawn. So wait for it to
        // settle, then focus a window here unless one already is.
        let spaceRefocus =
            "sleep 0.35; space=$(\(yabai) -m query --spaces --space 2>/dev/null | \(field("index")));"
            + " focused=$(\(yabai) -m query --windows --window 2>/dev/null | \(field("space")));"
            + " if [ -n \"$space\" ] && [ \"$focused\" != \"$space\" ]; then"
            + " \(yabai) -m window --focus first >/dev/null 2>&1; fi"
        return [
            ("macarchy_mission_control_exit", "mission_control_exit", missionControl),
            ("macarchy_refocus_space", "space_changed", spaceRefocus),
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
