import AppKit
import Foundation
import Macarchy

/// The shell's native side effects, replaceable by recorders in tests.
@MainActor
struct ShellActions {
    var revealSettings: @MainActor () -> Void
    var quit: @MainActor () -> Void

    static var live: Self {
        Self(revealSettings: { DiagnosticActions.live.reveal() }, quit: { AppDelegate.quit() })
    }
}

extension BridgeRouter {
    /// The settings window's frame: its state, preferences, the title bar's drag
    /// area, the activity log and the app-wide actions.
    func registerShell(model: AppModel, surface: WebSurface, actions: ShellActions = .live) {
        register("shell.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return model.shellState()
        }
        register("shell.setPreferences") { [weak surface] (params: ShellPreferences) in
            if let raw = params.selectedPane, let pane = Pane(rawValue: raw) {
                InterfacePreferences.selectedPane = pane
            }
            if let visible = params.sidebarVisible { InterfacePreferences.sidebarVisible = visible }
            if let mode = params.appearance {
                InterfacePreferences.appearance = mode
                surface?.webView.window?.appearance = mode.nsAppearance
            }
            return Null()
        }
        register("shell.setTitlebar") { [weak surface] (params: TitlebarParams) in
            surface?.webView.titlebarHeight = params.height
            surface?.webView.titlebarControls = params.controls.map(\.cgRect)
            return Null()
        }
        registerLog(model: model)
        register("shell.restartAll") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let results = await model.daemons.restartAll()
            return RestartAllResult(outcome: DaemonMonitor.outcome(of: results))
        }
        register("shell.revealSettings") { [weak model] (_: Empty) in
            actions.revealSettings()
            model?.log.note("reveal settings", "Opened in Finder")
            return Null()
        }
        register("shell.quit") { (_: Empty) in
            actions.quit()
            return Null()
        }
    }

    /// Reading the log never writes to it, so a page that reads again on
    /// `shell.logChanged` cannot loop.
    private func registerLog(model: AppModel) {
        register("shell.getLog") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return LogState(entries: model.log.entries.map(LogEntry.init))
        }
        register("shell.clearLog") { [weak model] (_: Empty) in
            model?.log.clear()
            return Null()
        }
    }
}

extension LogEntry {
    init(_ entry: CommandLog.Entry) {
        self.init(
            id: entry.id.uuidString, command: entry.command, detail: entry.detail, ok: entry.ok,
            at: entry.at.timeIntervalSince1970, status: entry.status.map(Int.init),
            category: entry.category)
    }
}

extension AppearanceMode {
    /// Nil follows the system.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// What the shell is sent, built from the same models the status menu reads,
/// so every entry point shows the same state.
extension AppModel {
    func shellState() -> ShellState {
        ShellState(
            selectedPane: InterfacePreferences.selectedPane.rawValue,
            sidebarVisible: InterfacePreferences.sidebarVisible,
            setupRequired: !FileManager.default.fileExists(atPath: settingsStore.url.path)
                || LegacyLayout.linkRemains,
            appearance: .init(accent: accentHex, mode: InterfacePreferences.appearance),
            services: .init(running: daemons.runningCount, total: daemons.installed.count),
            version: Self.version,
            serviceList: daemons.installed.map {
                .init(
                    id: .init($0), name: $0.displayName,
                    state: ShellState.Service.State(daemons.states[$0]))
            })
    }

    /// Setup health shows the same words for a build without a version.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development build"
    }

    /// The theme's border colour, or the system accent before any theme
    /// applies.
    var accentHex: String {
        if let hex = TerminalPalette.rgb(previewTheme?.manifest?.colors.borderActive) { return hex }
        return NSColor.controlAccentColor.hexString
    }
}

extension NSColor {
    var hexString: String {
        guard let srgb = usingColorSpace(.sRGB) else { return "#0a84ff" }
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(
            format: "#%02x%02x%02x", channel(srgb.redComponent), channel(srgb.greenComponent),
            channel(srgb.blueComponent))
    }
}

/// Window preferences the React shell keeps: the selected pane, the sidebar's
/// visibility and the window's appearance.
enum InterfacePreferences {
    private static let paneKey = "interface.selectedPane"
    private static let sidebarKey = "sidebarVisible"
    private static let appearanceKey = "interface.appearance"

    static var selectedPane: Pane {
        get {
            Preferences.store.string(forKey: paneKey).flatMap(Pane.init(rawValue:)) ?? .home
        }
        set { Preferences.store.set(newValue.rawValue, forKey: paneKey) }
    }

    static var sidebarVisible: Bool {
        get { Preferences.store.object(forKey: sidebarKey) as? Bool ?? true }
        set { Preferences.store.set(newValue, forKey: sidebarKey) }
    }

    static var appearance: AppearanceMode {
        get {
            Preferences.store.string(forKey: appearanceKey).flatMap(AppearanceMode.init(rawValue:))
                ?? .system
        }
        set { Preferences.store.set(newValue.rawValue, forKey: appearanceKey) }
    }
}
