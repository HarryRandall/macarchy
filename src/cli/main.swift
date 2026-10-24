import Foundation
import Macarchy
import Darwin

func require(_ result: CommandResult) throws {
    if !result.stdout.isEmpty { print(result.stdout) }
    guard result.ok else { throw ConfigurationError(result.stderr) }
}

let usage = """
    Usage: macarchy <command>

      setup [--keep|--replace] [--no-apply]
                                  Set up this Mac, start the services and apply the
                                  theme. --keep layers onto your existing configs
                                  (default); --replace starts from defaults.
                                  --no-apply only writes the files: no services are
                                  started and no theme is applied.
      services                    Start or restart yabai, skhd, SketchyBar and borders.
      uninstall                   Restore the files setup replaced and restart the
                                  services.
      doctor                      Check dependencies, services and configuration.
      apply                       Reapply every saved setting to the desktop.
      theme <name>|next|prev      Switch theme.
      wallpaper <theme> <path>    Choose a theme's wallpaper (path inside the theme).
      rules [toggle]              Reapply window rules, or float/tile the focused window.
      bar toggle                  Show or hide the menu bar.
      space <number>              Go to a Space, telling the bar first so it shows the
                                  new Space before macOS has switched.
      widget list                 List the bar widgets that can be added.
      widget check <id|folder>    Check a widget's files and say what to fix.
      widget run                  Keep the bar's widgets updated until Control-C, as the
                                  app does. For trying widgets without the app.
      widget click <instance>     Run by the bar when a widget is clicked.
      widget trigger <event>      Run by the bar to update the widgets that listen for
                                  an event, such as windows_changed.
      switcher                    Open the theme switcher in the running app.
      restore <snapshot> [--apply]
      startup yabai|sketchybar|borders   Run by the startup files at login.
    """

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first {
    case "setup":
        let existing: Setup.Existing = args.contains("--replace") ? .replace : .keep
        // The CLI lives inside the app bundle, so its bundle is the app to link.
        let app = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
        let applyToDesktop = !args.contains("--no-apply")
        let report = await SetupSession().run(
            existing: existing, app: app, applyToDesktop: applyToDesktop)
        // Failed commands are already among the lines, worded as the app shows them.
        for line in report.lines where !line.isEmpty { print(line) }
        if let failure = report.failure { throw ConfigurationError(failure) }
        if report.commands.contains(where: { !$0.ok }) {
            throw ConfigurationError(
                "The files are set up, but not everything started. Check with: macarchy doctor")
        }
        print(
            applyToDesktop
                ? "Done. Check everything with: macarchy doctor"
                : "Files are set up. Start the services with: macarchy services")
    case "services":
        var failed = false
        for result in await Setup.startServices() {
            print(
                (result.ok ? "ok   " : "FAIL ") + result.command
                    + (result.ok ? "" : ": " + result.summary))
            failed = failed || !result.ok
        }
        if failed { exit(1) }
    case "uninstall":
        let report = try await SetupSession().restoreOriginals()
        for line in report.lines where !line.isEmpty { print(line) }
        if report.commands.contains(where: { !$0.ok }) { exit(1) }
    case "doctor": try require(await Doctor.check())
    case "apply": try await DesktopConfiguration.apply()
    case "startup":
        guard args.count == 2 else {
            throw ConfigurationError("Usage: macarchy startup yabai|borders|sketchybar")
        }
        if args[1] == "borders" {
            try await Startup.applyCorners()
            // Replace the startup process; the daemon must not inherit the command timeout.
            let settings = try SettingsStore().read()
            let theme = settings.currentTheme.flatMap {
                Theme.load(from: Paths.themesDirectory.appending(path: $0))
            }
            let borders = Paths.borders
            let values =
                [borders] + BorderCommand.arguments(values: settings.flatValues, theme: theme)
            let pointers = values.map { strdup($0) }
            defer { pointers.forEach { free($0) } }
            var argv = pointers + [nil]
            execv(borders, &argv)
            throw ConfigurationError("Could not start borders: \(String(cString: strerror(errno)))")
        }
        try await OperationLock.run { try await Startup.apply(args[1]) }
    case "theme":
        guard args.count == 2 else {
            throw ConfigurationError("Usage: macarchy theme <name>|next|prev")
        }
        try require(await ThemeApplication().apply(name: args[1]))
    case "wallpaper":
        guard args.count == 3 else {
            throw ConfigurationError("Usage: macarchy wallpaper <theme> <relative-path>")
        }
        try require(await ThemeApplication().chooseWallpaper(theme: args[1], path: args[2]))
    case "rules":
        switch args.dropFirst().first {
        case "toggle": try await WindowRules.toggle()
        case "window-created": try await WindowRules.windowCreated()
        default:
            let settings = try SettingsStore().read()
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [])
        }
    case "switcher":
        // Handled by the running app; opening it first covers a quit app.
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("io.github.harryrandall.macarchy.switcher"), object: nil,
            userInfo: nil, deliverImmediately: true)
    case "space":
        guard args.count == 2, let space = Int(args[1]), (1...99).contains(space) else {
            throw ConfigurationError("Usage: macarchy space <number>")
        }
        // Heard by the running app, which repaints the bar from what it already
        // knows; then yabai switches, which takes a moment to animate.
        DistributedNotificationCenter.default().postNotificationName(
            WidgetActions.spaceNotification, object: nil, userInfo: ["space": space],
            deliverImmediately: true)
        let yabai = Paths.yabai
        var argv: [UnsafeMutablePointer<CChar>?] =
            [yabai, "-m", "space", "--focus", String(space)].map { strdup($0) } + [nil]
        execv(yabai, &argv)
        throw ConfigurationError("yabai could not be started")
    case "bar":
        guard args.dropFirst().first == "toggle" else { throw ConfigurationError(usage) }
        try require(await Integrations().sketchybar(["--bar", "hidden=toggle"]))
    case "widget":
        switch (args.dropFirst().first, args.count) {
        case ("list", 2):
            for line in WidgetReport.list() { print(line) }
        case ("check", 3):
            let report = WidgetReport.check(args[2])
            for line in report.lines { print(line) }
            if !report.ok { exit(1) }
        case ("run", 2):
            // Only the widget items, so the rest of the bar is left as it is.
            var configuration = try BarConfigurationStore().load() ?? BarConfiguration()
            configuration.components = configuration.components.filter(\.isWidget)
            configuration.geometry = [:]
            guard !configuration.components.isEmpty else {
                throw ConfigurationError("The bar has no widgets on it")
            }
            // Clicks reach this copy of the CLI, with the same home, so a
            // development build can be tried without installing it.
            var look = WidgetLook.current()
            let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let home = ProcessInfo.processInfo.environment["MACARCHY_HOME"]
            look.command =
                (home.map { "MACARCHY_HOME=\(Shell.quote($0)) " } ?? "") + Shell.quote(executable)
            try await BarCommands.replay(configuration, integrations: Integrations(), widgets: look)
            let host = WidgetHost()
            await host.start()
            print("Updating \(configuration.components.count) widgets. Stop with Control-C.")
            var reported: [String: String] = [:]
            while true {
                try await Task.sleep(for: .seconds(2))
                let problems = await host.problems
                for (id, message) in problems.sorted(by: { $0.key < $1.key })
                where reported[id] != message {
                    print("\(id): \(message)")
                }
                reported = problems
            }
        case ("click", 3):
            let outcome = try await WidgetActions.click(
                args[2], configuration: try BarConfigurationStore().load(),
                catalogue: WidgetCatalogue().read())
            if case .dropdown(let instance) = outcome {
                // Drawn by the running app; nothing happens if it is not running.
                DistributedNotificationCenter.default().postNotificationName(
                    WidgetActions.dropdownNotification, object: nil,
                    userInfo: ["instance": instance], deliverImmediately: true)
            }
        case ("trigger", 3):
            guard WidgetManifest.events.contains(args[2]) else {
                throw ConfigurationError(
                    "There is no widget event called \(args[2]). Events: "
                        + WidgetManifest.events.joined(separator: ", "))
            }
            // Heard by the running app; nothing happens if it is not running.
            DistributedNotificationCenter.default().postNotificationName(
                WidgetActions.triggerNotification, object: nil, userInfo: ["event": args[2]],
                deliverImmediately: true)
        default:
            throw ConfigurationError(
                "Usage: macarchy widget list | check <id|folder> | run | click <instance>"
                    + " | trigger <event>")
        }
    case "restore":
        guard args.count >= 2 else {
            throw ConfigurationError("Usage: macarchy restore <snapshot> [--apply]")
        }
        let store = SnapshotStore()
        guard let snapshot = store.list().first(where: { $0.id == args[1] }) else {
            throw ConfigurationError("Snapshot not found")
        }
        if args.contains("--apply") {
            try await DesktopConfiguration.restore(snapshot, store: store)
        } else {
            try await store.restoreLocked(snapshot)
            print("Files restored. Run macarchy apply to update the desktop.")
        }
    default:
        print(usage)
        if !args.isEmpty, args.first != "help", args.first != "--help" { exit(2) }
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
