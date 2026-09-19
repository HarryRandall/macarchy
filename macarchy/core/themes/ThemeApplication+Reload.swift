import Foundation

extension ThemeApplication {
    func updateAppearance(_ theme: Theme) async -> CommandResult? {
        let dark = await integrations.execute(
            "/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])
        guard (dark.stdout == "Dark") != theme.dark else { return nil }
        let result = await integrations.execute(
            "/usr/bin/osascript",
            [
                "-e",
                "tell application \"System Events\" to tell appearance preferences to set dark mode to \(theme.dark)"
            ])
        return result.ok ? nil : result
    }

    func refreshApplications() async {
        for (signal, process) in [("USR2", "ghostty"), ("USR2", "Ghostty"), ("WINCH", "nvim")] {
            _ = await integrations.execute("/usr/bin/pkill", ["-" + signal, "-x", process])
        }
        let btop = await integrations.execute("/usr/bin/pkill", ["-USR2", "-x", "btop"])
        guard !btop.ok else { return }
        // Some btop builds redraw through their terminal rather than SIGUSR2.
        let processes = await integrations.execute("/bin/ps", ["-axo", "tty=,comm="])
        var terminals = Set<String>()
        for line in processes.stdout.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count >= 2,
                URL(fileURLWithPath: String(fields[1])).lastPathComponent == "btop",
                fields[0] != "??", !fields[0].contains("/")
            else { continue }
            terminals.insert(String(fields[0]))
        }
        for terminal in terminals {
            guard
                let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/" + terminal))
            else { continue }
            try? handle.write(contentsOf: Data([0x12]))
            try? handle.close()
        }
    }
}
