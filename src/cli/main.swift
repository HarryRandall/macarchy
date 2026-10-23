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
      uninstall                   Stop Macarchy's services and give the daemons back
                                  the agents and files they had before setup.
      doctor                      Check dependencies, services and configuration.
      apply                       Reapply every saved setting to the desktop.
      theme <name>|next|prev      Switch theme.
      wallpaper <theme> <path>    Choose a theme's wallpaper (path inside the theme).
      rules [toggle]              Reapply window rules, or float/tile the focused window.
      bar toggle                  Show or hide the menu bar.
      switcher                    Open the theme switcher in the running app.
      restore <snapshot> [--apply]
      startup yabai|sketchybar|borders   Run by the startup files at login.
    """

let args = Array(CommandLine.arguments.dropFirst())
// Startup files run the CLI at login, possibly before the app has moved the
// old folder, so the CLI moves it too.
LegacyLayout.migrate()
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
    case "bar":
        guard args.dropFirst().first == "toggle" else { throw ConfigurationError(usage) }
        try require(await Integrations().sketchybar(["--bar", "hidden=toggle"]))
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
