import Foundation

public enum DesktopConfiguration {
    public static func apply(integrations: Integrations = Integrations()) async throws {
        let settings = try SettingsStore().read()
        if let name = settings.currentTheme {
            let result = await ThemeApplication(integrations: integrations).apply(name: name)
            guard result.ok else { throw ConfigurationError(result.stderr) }
        }
        try await Startup.apply("yabai", integrations: integrations)
        try await Startup.apply("sketchybar", integrations: integrations)
        try await Startup.applyCorners(integrations: integrations)
    }
}

extension Startup {
    public static func applyCorners(integrations: Integrations = Integrations()) async throws {
        guard let radius = try SettingsStore().load()["BORDER_RADIUS"] else { return }
        let result: CommandResult
        if radius == "system" {
            let current = await integrations.globalDefault("NSConvolutionOverride1")
            if !current.ok, current.stderr.contains("does not exist") { return }
            result = await integrations.removeGlobalDefault("NSConvolutionOverride1")
        } else {
            result = await integrations.setGlobalDefault("NSConvolutionOverride1", float: radius)
        }
        guard result.ok else { throw ConfigurationError(result.summary) }
    }
}
