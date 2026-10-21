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
    }

    var body: some Scene {
        Window("Macarchy", id: "main") {
            RootView()
                .environment(model)
                .task { await model.loadEverything() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Search…") {
                    model.modal.present(inContent: true) { CommandPalette() }
                }
                .keyboardShortcut("k", modifiers: .command)

                Button(model.consoleOpen ? "Hide Console" : "Show Console") {
                    model.consoleOpen.toggle()
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

        MenuBarExtra {
            StatusMenu()
                .environment(model)
        } label: {
            StatusLabel()
        }
    }
}
