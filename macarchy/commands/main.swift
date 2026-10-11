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
                                  Set up this Mac. --keep layers onto your existing
                                  configs (default); --replace starts from defaults.
      uninstall                   Restore the files setup replaced.
      doctor                      Check dependencies, services and configuration.
      apply                       Reapply every saved setting to the desktop.
      theme <name>|next|prev      Switch theme.
      wallpaper <theme> <path>    Choose a theme's wallpaper (path inside the theme).
      rules [toggle]              Reapply window rules, or float/tile the focused window.
      bar toggle                  Show or hide the menu bar.
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
        for line in try Setup.run(existing: existing, app: app) { print(line) }
        if !args.contains("--no-apply"), let theme = try SettingsStore().read().currentTheme {
            try require(await ThemeApplication().apply(name: theme))
        }
        print("Done. Restart the services from the app, or run: macarchy doctor")
    case "uninstall":
        for line in try Setup.uninstall() { print(line) }
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
        try await Startup.apply(args[1])
    case "theme":
        guard args.count == 2 else {
            throw ConfigurationError("Usage: macarchy theme <name>|next|prev")
        }
        try require(await ThemeApplication().apply(name: args[1]))
    case "wallpaper":
        guard args.count == 3 else {
            throw ConfigurationError("Usage: macarchy wallpaper <theme> <relative-path>")
        }
        let directory = Paths.themesDirectory.appending(path: args[1])
        _ = try Theme.read(from: directory).wallpaperURL(in: directory, selected: args[2])
        try SettingsStore().update { $0.wallpapers[args[1]] = args[2] }
        if try SettingsStore().read().currentTheme == args[1] {
            try require(await ThemeApplication().apply(name: args[1]))
        }
    case "rules":
        switch args.dropFirst().first {
        case "toggle": try await WindowRules.toggle()
        case "window-created": try await WindowRules.windowCreated()
        default:
            let settings = try SettingsStore().read()
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [])
        }
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
