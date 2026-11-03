import Foundation

/// InstantSpaceSwitcher switches Spaces with no slide, by sending the Dock
/// a very fast swipe. yabai's own switch slides for about half a second on
/// macOS 27, so `macarchy space` uses this one whenever it is installed.
///
/// It stays where Homebrew puts it, in Applications: macOS grants
/// Accessibility and Input Monitoring to the app there, so a copy in
/// Macarchy's folder would lose them. Macarchy only calls its command line
/// tool, from skhd, whose own Accessibility covers it.
public enum InstantSpaceSwitcher {
    public static let package = ToolInstaller.Package(
        id: "instant-space-switcher", name: "InstantSpaceSwitcher",
        formula: "jurplel/tap/instant-space-switcher", cask: true,
        provides: "InstantSpaceSwitcher")

    public static let bundleIdentifier = "com.interversehq.InstantSpaceSwitcher"

    /// The app, or nil when it is not installed. While it runs, its own
    /// hotkeys switch Spaces, with its guard against overshooting a burst.
    public static var app: URL? {
        Paths.applicationDirectories.map { $0.appending(path: "InstantSpaceSwitcher.app") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Its command line tool, or nil when it is not installed.
    public static var cli: String? {
        app.map { $0.appending(path: "Contents/MacOS/ISSCli").path }
            .flatMap { FileManager.default.isExecutableFile(atPath: $0) ? $0 : nil }
    }

    /// Whether Space switches are instant, for Health.
    static var healthCheck: HealthCheck {
        cli == nil
            ? HealthCheck(
                .optional, "Instant Space switching", .unknown,
                "Spaces slide for about half a second when switching",
                fix: "Tick InstantSpaceSwitcher under Optional in setup to install it")
            : HealthCheck(
                .optional, "Instant Space switching", .passed,
                "Spaces switch at once through InstantSpaceSwitcher")
    }

    /// Switches to Space `index` with no slide, or says it could not, as
    /// without permission or with several displays, so yabai can instead.
    /// Its numbering is per display, so with several it is not used.
    static func focus(_ index: Int, integrations: Integrations) async -> Bool {
        guard let cli, SpacesReading.currentSpaceIDs()?.count == 1 else { return false }
        return await integrations.execute(cli, ["index", String(index)]).ok
    }
}
