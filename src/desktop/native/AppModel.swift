import AppKit
import Foundation
import Macarchy
import Observation

@MainActor
@Observable
final class AppModel {
    let log: CommandLog
    /// The last layout read, for the Home summary. The Layout page itself
    /// reads and edits through `YabaiLayout`.
    var layout: LayoutSnapshot?
    let settingsStore: SettingsStore
    let themes: ThemeCatalog
    let daemons: DaemonMonitor
    let snapshots: SnapshotBrowser
    let menuBar: MenuBarModel
    let shortcuts: ShortcutsModel
    let backend: Integrations
    /// Opening the app at login; tests replace it with a recorder.
    var loginItem = LoginItem.current
    /// Opens a script in Terminal, returning why it could not. Tests replace
    /// it; an isolated run never opens anything.
    var openInTerminal: @MainActor (URL) -> String? = { script in
        guard !DesktopIsolation.isActive else {
            return "This run is isolated from the desktop, so Terminal was not opened"
        }
        guard
            let terminal = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Terminal")
        else { return "Terminal could not be found" }
        NSWorkspace.shared.open(
            [script], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
        return nil
    }

    init(backend: Integrations = Integrations(), settingsStore: SettingsStore = SettingsStore()) {
        let log = CommandLog()
        self.log = log
        self.backend = backend
        self.setupSession = SetupSession(integrations: backend)
        self.settingsStore = settingsStore
        self.themes = ThemeCatalog(backend: backend, log: log)
        self.daemons = DaemonMonitor(backend: backend, log: log)
        self.snapshots = SnapshotBrowser()
        self.menuBar = MenuBarModel(backend: backend, log: log)
        self.shortcuts = ShortcutsModel(log: log)
    }

    var previewTheme: InstalledTheme? {
        if let current = themes.themes.first(where: { $0.name == themes.current }) {
            return current
        }
        guard let wallpaper = desktopWallpaper?.resolvingSymlinksInPath() else { return nil }
        return themes.themes.first { theme in
            theme.availableBackgrounds.contains { $0.resolvingSymlinksInPath() == wallpaper }
        }
    }

    private var desktopWallpaper: URL? {
        guard let screen = NSScreen.main else { return nil }
        return NSWorkspace.shared.desktopImageURL(for: screen)
    }

    var currentThemeWallpaper: URL? { desktopWallpaper ?? previewTheme?.wallpaperURL }

    var advancedConfiguration: AdvancedConfiguration {
        AdvancedConfiguration(integrations: backend)
    }
    var setupSession: SetupSession

    var yabaiLayout: YabaiLayout { YabaiLayout(integrations: backend, store: settingsStore) }

    /// Reads the layout without changing it. Failures leave the last reading.
    @discardableResult
    func refreshLayout() async -> LayoutSnapshot? {
        do {
            let snapshot = try await yabaiLayout.read()
            // An unchanged assignment would still notify `StateBroadcast`.
            if layout != snapshot { layout = snapshot }
            return snapshot
        } catch {
            log.failure("read layout", error.localizedDescription)
            return nil
        }
    }

    func loadEverything() async {
        themes.reload()
        await refreshLayout()
        await daemons.refresh()
        snapshots.refresh()
        await menuBar.hydrate()
    }
}
