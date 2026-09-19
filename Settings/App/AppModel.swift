import Foundation
import Desktop
import Observation

@MainActor
@Observable
final class AppModel {
    let log: CommandLog
    let layout: LayoutModel
    let themes: ThemeCatalog
    let daemons: DaemonMonitor
    let borders: BordersModel
    let snapshots: SnapshotBrowser
    let menuBar: MenuBarModel
    let rc: RCGenerator
    let rules: RulesModel
    let shortcuts: ShortcutsModel

    var selection: Pane? = .layout

    init(backend: StackBackend = CLIBackend()) {
        let log = CommandLog()
        self.log = log
        self.layout = LayoutModel(backend: backend, log: log)
        self.themes = ThemeCatalog(backend: backend, log: log)
        self.daemons = DaemonMonitor(backend: backend, log: log)
        self.borders = BordersModel(backend: backend, log: log)
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
        // bordersrc reads settings at run time, so it only needs regenerating
        // when the template itself changes — on launch is enough.
        rc.generateBordersRC()
        rc.generateYabaiRC()
        await menuBar.hydrate()
        rc.generateSketchybarRC()
    }
}
