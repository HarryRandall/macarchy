import Foundation
import Macarchy
import Observation

@MainActor
@Observable
final class AppModel {
    let log: CommandLog
    let layout: LayoutModel
    let themes: ThemeCatalog
    let daemons: DaemonMonitor
    let borders: BordersModel
    let bordersEditor: BordersEditor
    let snapshots: SnapshotBrowser
    let menuBar: MenuBarModel
    let rc: RCGenerator
    let rules: RulesModel
    let shortcuts: ShortcutsModel

    var selection: Pane? = .layout

    init(backend: Integrations = Integrations()) {
        let log = CommandLog()
        self.log = log
        self.layout = LayoutModel(backend: backend, log: log)
        self.themes = ThemeCatalog(backend: backend, log: log)
        self.daemons = DaemonMonitor(backend: backend, log: log)
        let borders = BordersModel(backend: backend, log: log)
        self.borders = borders
        let themes = self.themes
        self.bordersEditor = BordersEditor { appearance in
            try await borders.commit(appearance, themes: themes)
        }
        self.snapshots = SnapshotBrowser(log: log)
        self.menuBar = MenuBarModel(backend: backend, log: log)
        self.rc = RCGenerator(log: log)
        self.rules = RulesModel(backend: backend, log: log)
        self.shortcuts = ShortcutsModel(log: log)
    }

    /// Reads a key off whichever theme is currently applied.
    func currentThemeValue(_ key: String) -> String? {
        guard let name = themes.current else { return nil }
        return themes.themes.first { $0.name == name }?.values[key]
    }

    var currentThemePalette: GhosttyPalette? {
        guard let name = themes.current else { return nil }
        return themes.themes.first { $0.name == name }?.palette
    }

    var currentThemeWallpaper: URL? {
        guard let name = themes.current else { return nil }
        return themes.themes.first { $0.name == name }?.wallpaperURL
    }

    func loadEverything() async {
        themes.reload()
        await layout.hydrate()
        await borders.hydrate()
        await daemons.refresh()
        snapshots.refresh()
        await menuBar.hydrate()
    }
}
