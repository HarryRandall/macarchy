import Foundation
import OSLog

/// The parts of applying a theme that reach the whole login session rather
/// than Macarchy's own files and daemons: the desktop picture, the system
/// appearance and running applications.
///
/// Every entry point builds `ThemeApplication` with `current`, so a
/// development build replaces them in this one place.
public struct DesktopEffects: Sendable {
    public typealias SetWallpaper = @Sendable (URL) async throws -> Void
    /// Returns the failure, or nil once the appearance matches `dark`.
    public typealias SetAppearance = @Sendable (_ dark: Bool, Integrations) async -> CommandResult?
    public typealias RefreshApplications = @Sendable (Integrations) async -> Void

    public var setWallpaper: SetWallpaper
    public var setAppearance: SetAppearance
    public var refreshApplications: RefreshApplications

    public init(
        setWallpaper: @escaping SetWallpaper, setAppearance: @escaping SetAppearance,
        refreshApplications: @escaping RefreshApplications
    ) {
        self.setWallpaper = setWallpaper
        self.setAppearance = setAppearance
        self.refreshApplications = refreshApplications
    }

    public static let live = DesktopEffects(
        setWallpaper: { url in _ = try await MainActor.run { try Wallpaper.set(url) } },
        setAppearance: { await ThemeApplication.updateAppearance(dark: $0, integrations: $1) },
        refreshApplications: { await ThemeApplication.refreshApplications(integrations: $0) })

    /// Effects that only describe what they would have done.
    public static func recording(_ record: @escaping @Sendable (String) -> Void) -> DesktopEffects {
        DesktopEffects(
            setWallpaper: { record("set wallpaper \(Paths.display($0))") },
            setAppearance: { dark, _ in
                record("set appearance \(dark ? "dark" : "light")")
                return nil
            },
            refreshApplications: { _ in record("refresh Ghostty and Neovim") })
    }

    /// `live`, except that a debug build run with `MACARCHY_DEBUG_DRY_THEMES=1`
    /// logs these effects instead, so it can sit beside the installed app.
    public static var current: DesktopEffects {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MACARCHY_DEBUG_DRY_THEMES"] == "1" {
            let log = Logger(subsystem: "io.github.harryrandall.macarchy", category: "dry-run")
            return recording { note in log.notice("dry run: \(note, privacy: .public)") }
        }
        #endif
        return live
    }
}
