import Foundation
import MacarchyKit
import Observation

enum Pane: String, CaseIterable, Identifiable, Hashable {
    case themes, borders, menuBar, layout, rules, shortcuts, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themes: "Themes"
        case .borders: "Borders"
        case .menuBar: "Menu Bar"
        case .layout: "Layout"
        case .rules: "Rules"
        case .shortcuts: "Shortcuts"
        case .advanced: "Advanced"
        }
    }

    var symbol: String {
        switch self {
        case .themes: "paintpalette"
        case .borders: "square.dashed"
        case .menuBar: "menubar.rectangle"
        case .layout: "rectangle.3.group"
        case .rules: "flag"
        case .shortcuts: "command"
        case .advanced: "gearshape"
        }
    }

    /// Grouped by what you are changing, not by which daemon owns it.
    enum Group: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case behaviour = "Behaviour"
        case system = "System"

        var id: String { rawValue }

        var panes: [Pane] {
            switch self {
            case .appearance: [.themes, .borders, .menuBar]
            case .behaviour: [.layout, .rules, .shortcuts]
            case .system: [.advanced]
            }
        }
    }
}

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
        self.rules = RulesModel(log: log)
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
