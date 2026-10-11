import AppKit
import SwiftUI
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
    /// Dialogs are presented inside the window rather than as sheets, so the
    /// page behind one cannot be hovered or clicked while it is open.
    let modal = ModalRouter()

    /// Whether the command log is showing in its panel on the right. It lives
    /// here rather than in a view so the palette and the menu can open it.
    var consoleOpen = false

    private let backend: Integrations

    var selection: Pane? =
        Pane(rawValue: UserDefaults.standard.string(forKey: "selectedPane") ?? "home") ?? .home
    {
        didSet {
            UserDefaults.standard.set(selection?.rawValue, forKey: "selectedPane")
            guard !navigating, oldValue != selection else { return }
            if let oldValue { back.append(oldValue) }
            forward.removeAll()
        }
    }

    /// Where the arrows in the window's bar go. Panes are visited rather than
    /// opened, so the pair behaves like a browser's: going back banks the
    /// pane you left, and choosing a new one from the sidebar drops the
    /// forward trail.
    private var back: [Pane] = []
    private var forward: [Pane] = []
    private var navigating = false

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }

    func goBack() {
        guard let previous = back.popLast() else { return }
        if let current = selection { forward.append(current) }
        navigate(to: previous)
    }

    func goForward() {
        guard let next = forward.popLast() else { return }
        if let current = selection { back.append(current) }
        navigate(to: next)
    }

    private func navigate(to pane: Pane) {
        navigating = true
        selection = pane
        navigating = false
    }

    init(backend: Integrations = Integrations()) {
        let log = CommandLog()
        self.log = log
        self.backend = backend
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

    var currentThemePalette: GhosttyPalette? { previewTheme?.palette }

    var currentThemeWallpaper: URL? { desktopWallpaper ?? previewTheme?.wallpaperURL }

    var interfaceAccent: Color {
        previewTheme?.accent ?? Color(nsColor: .controlAccentColor)
    }

    /// The two signals `yabairc` registers to put the desktop back together
    /// after a long sleep. Reading them back is the only way to know they took:
    /// a signal that failed to register leaves no other trace.
    func wakeHelpersRegistered() async -> Bool {
        let result = await backend.execute(Paths.yabai, ["-m", "signal", "--list"])
        guard result.ok,
            let signals = try? JSONSerialization.jsonObject(with: Data(result.stdout.utf8))
                as? [[String: Any]]
        else { return false }
        let labels = Set(signals.compactMap { $0["label"] as? String })
        return labels.isSuperset(of: ["reload_sa", "restart_borders"])
    }

    /// Re-pins the sudo rule that lets the desktop-switching helper load. The
    /// system asks for the password itself; nothing here ever sees it.
    func repairScriptingAddition() async {
        log.record(await ScriptingAddition.repair())
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
