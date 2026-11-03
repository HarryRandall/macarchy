import AppKit
import Darwin
import Foundation
import Macarchy

func require(_ result: CommandResult) throws {
    if !result.stdout.isEmpty { print(result.stdout) }
    guard result.ok else { throw ConfigurationError(result.stderr) }
}

/// Tells the running app something. An isolated run must not reach the
/// installed app, which would act on the real desktop.
func announce(_ name: Notification.Name, _ userInfo: [AnyHashable: Any] = [:]) {
    AppNotice.post(name, userInfo)
}

let usage = """
    Usage: macarchy <command>

      setup [--tools=<list>] [--keep[=<list>]|--replace[=<list>]] [--install] [--no-apply]
                                  Set up this Mac, start the services and apply the
                                  theme. --tools names the tools to configure, from
                                  yabai, skhd, sketchybar and borders, separated by
                                  commas (default: those chosen last time, or all
                                  four); the others are left alone. --keep layers
                                  onto your existing yabai and skhd configs
                                  (default); --replace starts from defaults. Either
                                  can name tools, as in --replace=skhd, to choose
                                  for those alone. --install first installs chosen
                                  tools that are missing with Homebrew. --no-apply
                                  only writes the files: no services are started
                                  and no theme is applied.
      services                    Start or restart the tools setup configured.
      uninstall [--remove-tools]  Stop Macarchy's services and give the daemons back
                                  the agents and files they had before setup.
                                  --remove-tools also removes the tools Macarchy
                                  installed with Homebrew; tools you had before are
                                  never removed.
      doctor                      Check dependencies, services and configuration.
      cleanup [--apply] [--restore <archive>]
                                  Show how old configuration outside Macarchy's folder
                                  would be cleaned up; --apply does it, archiving
                                  everything it deletes or changes first; --restore
                                  puts an archive back.
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
      widget fallback <instance>  Run by the bar to keep a clock going while the app
                                  is not running.
      switcher                    Open the theme switcher in the running app.
      restore <snapshot> [--apply]
                                  Put back the files in a snapshot; --apply also
                                  reapplies them and restarts skhd if needed.
      startup yabai|sketchybar|borders   Run by the startup files at login.
    """

/// The lines of `usage` for `command`, shown with its errors and `--help`.
/// A command with several forms, such as `widget`, gets all of them.
func usage(of command: String) -> String {
    var entries: [String] = []
    var inside = false
    for line in usage.components(separatedBy: "\n") {
        let entry = line.hasPrefix("  ") && !line.hasPrefix("   ")
        if entry {
            inside = line.split(separator: " ").first.map(String.init) == command
            if inside {
                entries.append(
                    (entries.isEmpty ? "Usage: macarchy" : "       macarchy") + line.dropFirst())
            }
        } else if inside, line.hasPrefix("        ") {
            entries.append(line)
        } else {
            inside = false
        }
    }
    return entries.isEmpty ? usage : entries.joined(separator: "\n")
}

let args = Array(CommandLine.arguments.dropFirst())
// Startup files run the CLI at login, possibly before the app has moved the
// old folder, so the CLI moves it too.
LegacyLayout.migrate()
let command = args.first ?? ""
let rest = Array(args.dropFirst())
do {
    func parse(
        flags: Set<String> = [], options: Set<String> = [], values: ClosedRange<Int> = 0...0,
        choices: [String]? = nil, conflicting: [Set<String>] = []
    ) throws -> CommandArguments {
        try CommandArguments(
            rest, usage: usage(of: command), flags: flags, options: options, values: values,
            choices: choices, conflicting: conflicting)
    }
    switch command {
    case "setup":
        let options = try parse(
            flags: ["--keep", "--replace", "--no-apply", "--install"],
            options: ["--tools", "--keep", "--replace"], conflicting: [["--keep", "--replace"]])
        try await setUp(options, usage: usage(of: command))
    case "services":
        _ = try parse()
        var failed = false
        let results = await Setup.startServices()
        if results.isEmpty { print("No services are installed.") }
        for result in results {
            print(
                (result.ok ? "ok   " : "FAIL ") + result.command
                    + (result.ok ? "" : ": " + result.summary))
            failed = failed || !result.ok
        }
        if failed { exit(1) }
    case "uninstall":
        try await uninstall(try parse(flags: ["--remove-tools"]))
    case "doctor":
        _ = try parse()
        try require(await Doctor.check())
    case "cleanup":
        let options = try parse(
            flags: ["--apply", "--restore"], values: 0...1,
            conflicting: [["--apply", "--restore"]])
        try await cleanUp(options, usage: usage(of: command))
    case "apply":
        _ = try parse()
        try await DesktopConfiguration.apply()
        print("Applied the saved settings.")
    case "startup":
        let options = try parse(values: 1...1, choices: ["yabai", "sketchybar", "borders"])
        await Startup.recordRun(options.values[0])
        if options.values[0] == "borders" {
            // Window corners are a separate preference; failing to set them
            // must not keep borders from starting.
            do { try await Startup.applyCorners() } catch {
                FileHandle.standardError.write(
                    Data("Window corners not set: \(error.localizedDescription)\n".utf8))
            }
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
        try await OperationLock.run { try await Startup.apply(options.values[0]) }
    case "theme":
        let options = try parse(values: 1...1)
        try require(await ThemeApplication().apply(name: options.values[0]))
    case "wallpaper":
        let options = try parse(values: 2...2)
        try require(
            await ThemeApplication().chooseWallpaper(
                theme: options.values[0], path: options.values[1]))
        print("Saved the wallpaper for \(options.values[0]).")
    case "rules":
        // `window-created` is run by yabai's signals and is not listed.
        let options = try parse(values: 0...1, choices: ["toggle", "window-created"])
        switch options.values.first {
        case "toggle": try await WindowRules.toggle()
        case "window-created": try await WindowRules.windowCreated()
        default:
            let settings = try SettingsStore().read()
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [])
            print("Applied the window rules.")
        }
    case "switcher":
        _ = try parse()
        // Handled by the running app, which listens for this notification;
        // nothing is listening when it is not open.
        guard !DesktopIsolation.isActive else { break }
        guard
            !NSRunningApplication.runningApplications(
                withBundleIdentifier: "io.github.harryrandall.macarchy"
            ).isEmpty
        else {
            throw ConfigurationError("Macarchy is not open. Open it, then try again.")
        }
        announce(Notification.Name("io.github.harryrandall.macarchy.switcher"))
    case "space":
        let options = try parse(values: 1...1)
        guard let space = Int(options.values[0]), (1...99).contains(space) else {
            throw CommandArguments.Invalid(
                message: "The Space must be a number from 1 to 99", usage: usage(of: command))
        }
        // Heard by the running app, which repaints the bar from what it already
        // knows; then yabai switches, which takes a moment to animate.
        announce(WidgetActions.spaceNotification, ["space": space])
        let yabai = Paths.yabai
        var argv: [UnsafeMutablePointer<CChar>?] =
            [yabai, "-m", "space", "--focus", String(space)].map { strdup($0) } + [nil]
        execv(yabai, &argv)
        throw ConfigurationError("yabai could not be started")
    case "bar":
        _ = try parse(values: 1...1, choices: ["toggle"])
        try require(await Integrations().sketchybar(["--bar", "hidden=toggle"]))
    case "widget":
        let forms = ["list", "check", "run", "click", "trigger", "fallback"]
        let form = rest.first ?? ""
        if rest.isEmpty || ["--help", "-h"].contains(form) {
            throw CommandArguments.Help(usage: usage(of: command))
        }
        guard forms.contains(form) else {
            throw CommandArguments.Invalid(
                message: "Unknown argument \(form)", usage: usage(of: command))
        }
        // The bar runs click and trigger with names it was given, taken as
        // written; the others are checked like any other command.
        let value: String
        if ["check", "click", "trigger", "fallback"].contains(form) {
            value = try CommandArguments.literal(
                Array(rest.dropFirst()), usage: usage(of: command))
        } else {
            _ = try CommandArguments(
                Array(rest.dropFirst()), usage: usage(of: command))
            value = ""
        }
        switch form {
        case "list":
            for line in WidgetReport.list() { print(line) }
        case "check":
            let report = WidgetReport.check(value)
            for line in report.lines { print(line) }
            if !report.ok { exit(1) }
        case "run":
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
            // Held until Control-C ends the process, so the clock's fallback
            // leaves the clock to this host.
            let presence = WidgetHostPresence.hold()
            defer { presence.map { _ = close($0) } }
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
        case "fallback":
            // The app updates the clock while it runs; this is for when it does not.
            guard !WidgetHostPresence.isHeld() else { break }
            try await WidgetHost.fallback(value)
        case "click":
            let outcome = try await WidgetActions.click(
                value, configuration: try BarConfigurationStore().load(),
                catalogue: WidgetCatalogue().read())
            if case .dropdown(let instance) = outcome {
                // Drawn by the running app; nothing happens if it is not running.
                announce(WidgetActions.dropdownNotification, ["instance": instance])
            }
        default:
            guard WidgetManifest.events.contains(value) else {
                throw ConfigurationError(
                    "There is no widget event called \(value). Events: "
                        + WidgetManifest.events.joined(separator: ", "))
            }
            // Heard by the running app; nothing happens if it is not running.
            announce(WidgetActions.triggerNotification, ["event": value])
        }
    case "restore":
        try await restore(try parse(flags: ["--apply"], values: 1...1))
    case "", "help", "--help", "-h":
        print(usage)
    default:
        FileHandle.standardError.write(Data("Unknown command \(command)\n\n\(usage)\n".utf8))
        exit(2)
    }
} catch let help as CommandArguments.Help {
    print(help.usage)
} catch let invalid as CommandArguments.Invalid {
    FileHandle.standardError.write(Data("\(invalid.message)\n\n\(invalid.usage)\n".utf8))
    exit(2)
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
