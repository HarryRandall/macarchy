import Macarchy
import SwiftUI

@main
struct SettingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    init() {
        // First, so the bar is brought up to date while the rest of the app
        // and its window are still being set up.
        WidgetHostController.shared.start()
        let model = AppModel()
        _model = State(initialValue: model)
        // The widgets need the app running, so the first launch after setup
        // opens it at login from then on, unless the person turns that off.
        if let problem = model.loginItem.turnOnOnce() {
            model.log.failure("open at login", problem)
        }
        // The switcher's hotkey must work before any window has opened.
        ThemeSwitcher.shared.attach(model)
        SettingsWindow.shared.attach(model)
        StateBroadcast.shared.start(model)
        Task { await model.loadEverything() }
    }

    // The settings window is an AppKit window the app opens itself; the menu
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
