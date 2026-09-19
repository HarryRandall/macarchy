import Foundation

// Prints the Swift port's output so it can be diffed against reference.sh.
// usage: ghosttyport <ghostty-config> <theme-ghostty-conf> <theme-name>
let args = CommandLine.arguments
guard args.count == 4,
      let config = try? String(contentsOfFile: args[1], encoding: .utf8),
      let themeConf = try? String(contentsOfFile: args[2], encoding: .utf8)
else { fputs("usage: ghosttyport <config> <theme.conf> <name>\n", stderr); exit(2) }

print(GhosttyApplier.transform(config: config, themeConf: themeConf, themeName: args[3]),
      terminator: "")
