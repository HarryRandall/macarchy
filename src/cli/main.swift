import Foundation
import Macarchy
import Darwin

func require(_ result: CommandResult) throws {
    if !result.stdout.isEmpty { print(result.stdout) }
    guard result.ok else { throw ConfigurationError(result.stderr) }
}

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first {
    case "doctor": try require(await Doctor.check())
    case "migrate": try Migration.run(); print("Migrated settings and startup configuration")
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
            let values =
                [Paths.borders]
                + BorderCommand.arguments(values: settings.legacyValues, theme: theme)
            let pointers = values.map { strdup($0) }
            defer { pointers.forEach { free($0) } }
            var argv = pointers + [nil]
            execv(Paths.borders, &argv)
            throw ConfigurationError("Could not start borders: \(String(cString: strerror(errno)))")
        }
        try await Startup.apply(args[1])
    case "theme":
        guard args.count == 2 else {
            throw ConfigurationError("Usage: macarchy theme <name>|next|prev")
        }
        try require(await ThemeApplication().apply(name: args[1]))
    case "background":
        guard args.count == 3 else {
            throw ConfigurationError("Usage: macarchy background <theme> <relative-path>")
        }
        let directory = Paths.themesDirectory.appending(path: args[1])
        _ = try Theme.read(from: directory)
        let image = directory.appending(path: args[2]).resolvingSymlinksInPath()
        guard image.path.hasPrefix(directory.resolvingSymlinksInPath().path + "/"),
            FileManager.default.fileExists(atPath: image.path)
        else { throw ConfigurationError("Invalid wallpaper path") }
        try SettingsStore().update { $0.wallpapers[args[1]] = args[2] }
        if try SettingsStore().read().currentTheme == args[1] {
            try require(await ThemeApplication().apply(name: args[1]))
        }
    case "theme-output":
        guard args.count == 3 else {
            throw ConfigurationError("Usage: macarchy theme-output <directory> btop|shell|nvim")
        }
        let directory = URL(fileURLWithPath: args[1])
        let outputs = ThemeOutputs(
            theme: try Theme.read(from: directory),
            ghostty: try String(
                contentsOf: directory.appending(path: "ghostty.conf"), encoding: .utf8))
        switch args[2] {
        case "btop": print(outputs.btop, terminator: "")
        case "shell": print(outputs.shell, terminator: "")
        case "nvim": print(outputs.nvim)
        default: throw ConfigurationError("Unknown output")
        }
    case "rules":
        switch args.dropFirst().first {
        case "toggle": try await WindowRules.toggle()
        case "window-created": try await WindowRules.windowCreated()
        default: try await WindowRules.apply(SettingsStore().read().floatingApps)
        }
    case "restore":
        guard args.count >= 2 else {
            throw ConfigurationError("Usage: macarchy restore <snapshot> [--apply]")
        }
        let store = SnapshotStore()
        guard let snapshot = store.list().first(where: { $0.id == args[1] }) else {
            throw ConfigurationError("Snapshot not found")
        }
        try store.restore(snapshot)
        if args.contains("--apply") {
            try await DesktopConfiguration.apply()
        } else {
            print("Files restored. Run macarchy apply to update the desktop.")
        }
    case "ghostty":
        guard args.count == 3 else {
            throw ConfigurationError("Usage: macarchy ghostty <theme-dir> <theme-name>")
        }
        let url = Paths.home.appending(path: ".config/ghostty/config")
        let original = try String(contentsOf: url, encoding: .utf8)
        let palette = try String(
            contentsOf: URL(fileURLWithPath: args[1]).appending(path: "ghostty.conf"),
            encoding: .utf8)
        try GhosttyConfig.transform(config: original, themeConf: palette, themeName: args[2]).write(
            to: url, atomically: true, encoding: .utf8)
    default:
        print(
            "macarchy: theme <name>|next|prev, apply, doctor, migrate, restore <id> [--apply], startup <integration>, rules"
        )
        if !args.isEmpty { exit(2) }
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
