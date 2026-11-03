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
            // Each key and signal is its own yabai process and none depends on
            // another, so they go together rather than one after another.
            let results = await withTaskGroup(of: (Int, CommandResult).self) { group in
                for (order, setting) in StartupConfiguration.yabaiKeys.enumerated() {
                    let value = values[setting.env] ?? setting.fallback
                    group.addTask {
                        (order, await integrations.yabaiWrite(setting.key, value: value))
                    }
                }
                for (order, signal) in signals.enumerated() {
                    group.addTask {
                        (
                            StartupConfiguration.yabaiKeys.count + order,
                            await integrations.execute(Paths.yabai, signal)
                        )
                    }
                }
                var collected: [(Int, CommandResult)] = []
                for await result in group { collected.append(result) }
                return collected.sorted { $0.0 < $1.0 }.map(\.1)
            }
            for result in results { try require(result) }
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [],
                integrations: integrations)
        case "sketchybar":
            try require(
                await integrations.sketchybar(
                    BarLook.arguments(
                        values: values, colours: .theme(settings.currentTheme))))
            let configuration = try bar(settings)
            try await BarCommands.replay(configuration, integrations: integrations)
            await fillWidgets(configuration, integrations: integrations)
        // borders is started by `macarchy startup borders` itself, which
        // replaces its own process with borders rather than calling this.
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
        // so the Spaces widget looks again.
        let reassert =
            "space=$(\(yabai) -m query --spaces --space 2>/dev/null | \(field("index")));"
            + " window=$(\(yabai) -m query --windows --window 2>/dev/null);"
            + " id=$(printf '%s\\n' \"$window\" | \(field("id")));"
            + " if [ -z \"$id\" ]; then \(yabai) -m window --focus first >/dev/null 2>&1;"
            + " elif [ \"$(printf '%s\\n' \"$window\" | \(field("space")))\" = \"$space\" ]; then"
            + " \(yabai) -m window --focus \"$id\" >/dev/null 2>&1; fi"
        let missionControl =
            "sleep 0.25; \(reassert); \(cli) widget trigger space_changed >/dev/null 2>&1"
        // Arriving on a Space, yabai first still reports the previous Space's
        // window as focused; a moment later macOS activates Finder or another
        // app with no window here, and no border is drawn. So wait for it to
        // settle, then focus a window here unless one already is. A Space
        // left again while waiting, as when switching quickly, is left alone:
        // focusing there would only pull focus about behind the newer switch.
        let spaceRefocus =
            "sleep 0.35; current=$(\(yabai) -m query --spaces --space 2>/dev/null);"
            + " [ -z \"$YABAI_SPACE_ID\" ]"
            + " || [ \"$(printf '%s\\n' \"$current\" | \(field("id")))\" = \"$YABAI_SPACE_ID\" ]"
            + " || exit 0;"
            + " space=$(printf '%s\\n' \"$current\" | \(field("index")));"
            + " focused=$(\(yabai) -m query --windows --window 2>/dev/null | \(field("space")));"
            + " if [ -n \"$space\" ] && [ \"$focused\" != \"$space\" ]; then"
            + " \(yabai) -m window --focus first >/dev/null 2>&1; fi"
        return [
            ("macarchy_mission_control_exit", "mission_control_exit", missionControl),
            ("macarchy_refocus_space", "space_changed", spaceRefocus),
            ("macarchy_refocus_destroyed", "window_destroyed", refocus),
            ("macarchy_refocus_terminated", "application_terminated", refocus)
        ].map { label, event, action in
            ["-m", "signal", "--add", "label=\(label)", "event=\(event)", "action=\(action)"]
        }
    }

    /// The bar to start. Until setup moves an earlier bar onto widgets, a
    /// person's own bar still builds its items and hides them as saved,
    /// while Macarchy's earlier bar, whose scripts are gone, shows the
    /// widgets it is about to move onto.
    static func bar(_ settings: SettingsDocument) throws -> BarConfiguration {
        let saved = try BarConfigurationStore().load()
        guard settings.barBeforeWidgets == true else { return saved ?? .widgetDefault }
        return WidgetMigration.moveBar(saved).configuration
    }
}
