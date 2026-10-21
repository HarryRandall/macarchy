import Foundation

extension ThemeApplication {
    static func updateAppearance(dark: Bool, integrations: Integrations) async -> CommandResult? {
        let current = await integrations.execute(
            "/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])
        guard (current.stdout == "Dark") != dark else { return nil }
        let result = await integrations.execute(
            "/usr/bin/osascript",
            [
                "-e",
                "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"
            ])
        return result.ok ? nil : result
    }

    /// Ghostty reloads its config on SIGUSR2; Neovim re-reads the colourscheme
    /// file from a resize handler. Neither being open is fine.
    static func refreshApplications(integrations: Integrations) async {
        for (signal, process) in [("USR2", "ghostty"), ("USR2", "Ghostty"), ("WINCH", "nvim")] {
            _ = await integrations.execute("/usr/bin/pkill", ["-" + signal, "-x", process])
        }
    }
}
