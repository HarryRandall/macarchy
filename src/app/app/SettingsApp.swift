import SwiftUI

@main
struct SettingsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Macarchy", id: "main") {
            RootView()
                .environment(model)
                .task { await model.loadEverything() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 620)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra("Macarchy", systemImage: "circle.lefthalf.filled") {
            StatusMenu()
                .environment(model)
        }
    }
}
