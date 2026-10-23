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
                // The page owns these; the menu only names them and passes
                // them on, since its key equivalents can reach AppKit first.
                Button("Search…") { SettingsWindow.shared.perform(.palette) }
                    .keyboardShortcut("k", modifiers: .command)

                Button("Show Logs") { SettingsWindow.shared.perform(.logs) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Back") { SettingsWindow.shared.perform(.back) }
                    .keyboardShortcut("[", modifiers: .command)

                Button("Forward") { SettingsWindow.shared.perform(.forward) }
                    .keyboardShortcut("]", modifiers: .command)
            }
        }
    }
}
