import Foundation
import MacarchyKit

// Headless companion to the app. theme-switch and the theme-cycling hotkey call
// this, so a ported surface has exactly one implementation regardless of whether
// a theme was applied from the GUI or the keyboard.

func usage() -> Never {
    fputs(
        """
        usage: macarchy <command>

          ghostty <theme-dir> <theme-name>   inline a theme's palette into ~/.config/ghostty/config

        """, stderr)
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { usage() }

switch command {
case "ghostty":
    guard arguments.count == 3 else { usage() }
    let themeDirectory = URL(fileURLWithPath: arguments[1])
    let themeName = arguments[2]

    let configURL = URL(fileURLWithPath: NSHomeDirectory()).appending(
        path: ".config/ghostty/config")
    let themeConfURL = themeDirectory.appending(path: "ghostty.conf")

    guard let config = try? String(contentsOf: configURL, encoding: .utf8) else {
        fputs("macarchy: no ghostty config at \(configURL.path)\n", stderr); exit(1)
    }
    guard let themeConf = try? String(contentsOf: themeConfURL, encoding: .utf8) else {
        fputs("macarchy: no ghostty.conf in \(themeDirectory.path)\n", stderr); exit(1)
    }

    let updated = GhosttyApplier.transform(
        config: config, themeConf: themeConf, themeName: themeName)
    do {
        try updated.write(to: configURL, atomically: true, encoding: .utf8)
    } catch {
        fputs("macarchy: could not write ghostty config: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
    print("  Ghostty: palette inlined (\(themeName))")

default:
    usage()
}
