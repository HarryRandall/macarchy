import AppKit
import Foundation
import Macarchy

extension BridgeRouter {
    /// The settings window's frame: its state, preferences, the classic window
    /// and the title bar's drag area.
    func registerShell(model: AppModel, surface: WebSurface) {
        register("shell.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return model.shellState()
        }
        register("shell.setPreferences") { (params: ShellPreferences) in
            if let raw = params.selectedPane, let pane = Pane(rawValue: raw),
                Pane.migrated.contains(pane)
            {
                InterfacePreferences.selectedPane = pane
            }
            if let visible = params.sidebarVisible { InterfacePreferences.sidebarVisible = visible }
            return Null()
        }
        register("shell.openClassic") { (params: OpenClassicParams) in
            AppDelegate.showClassicWindow(
                pane: params.pane.flatMap(Pane.init(rawValue:)), show: params.show)
            return Null()
        }
        register("shell.setTitlebar") { [weak surface] (params: TitlebarParams) in
            surface?.webView.titlebarHeight = params.height
            surface?.webView.titlebarControls = params.controls.map(\.cgRect)
            return Null()
        }
    }
}

/// What the shell is sent, built from the same models the status menu and the
/// classic window read, so every entry point shows the same state.
extension AppModel {
    func shellState() -> ShellState {
        ShellState(
            selectedPane: InterfacePreferences.selectedPane.rawValue,
            sidebarVisible: InterfacePreferences.sidebarVisible,
            setupRequired: !FileManager.default.fileExists(atPath: settingsStore.url.path),
            appearance: .init(accent: accentHex),
            services: .init(running: daemons.runningCount, total: Daemon.allCases.count))
    }

    /// The theme's border colour, as the classic window tints itself, or the
    /// system accent before any theme applies.
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

/// Window preferences the React shell keeps. The sidebar's visibility is
/// shared with the classic window; the selected pane is not, because the two
/// windows show different sets of panes.
enum InterfacePreferences {
    private static let paneKey = "interface.selectedPane"
    private static let sidebarKey = "sidebarVisible"

    static var selectedPane: Pane {
        get {
            UserDefaults.standard.string(forKey: paneKey).flatMap(Pane.init(rawValue:))
                .flatMap { Pane.migrated.contains($0) ? $0 : nil } ?? .layout
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: paneKey) }
    }

    static var sidebarVisible: Bool {
        get { UserDefaults.standard.object(forKey: sidebarKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: sidebarKey) }
    }
}
