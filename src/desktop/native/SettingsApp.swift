import SwiftUI

@main
struct SettingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        // The switcher's hotkey must work before any window has opened.
        ThemeSwitcher.shared.attach(model)
        SettingsWindow.shared.attach(model)
        AppDelegate.model = model
        model.openMigrated = { pane in SettingsWindow.shared.show(pane) }
        StateBroadcast.shared.start(model)
        Task { await model.loadEverything() }
    }

    // Both settings windows are AppKit windows the app opens itself; the menu
    // bar item is the only scene.
    var body: some Scene {
        MenuBarExtra {
            StatusMenu()
                .environment(model)
        } label: {
            StatusLabel()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                // Search and the console are still the classic window's; from
                // the React window they open it.
                Button("Search…") { AppDelegate.showClassicWindow(pane: nil, show: .search) }
                    .keyboardShortcut("k", modifiers: .command)

                Button(model.consoleOpen ? "Hide Console" : "Show Console") {
                    if model.consoleOpen {
                        model.consoleOpen = false
                    } else {
                        AppDelegate.showClassicWindow(pane: nil, show: .console)
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("Back") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!model.canGoBack)

                Button("Forward") { model.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!model.canGoForward)
            }
        }
    }
}
