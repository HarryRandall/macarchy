import SwiftUI

@main
struct MacarchySettingsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Macarchy Settings", id: "main") {
            RootView()
                .environment(model)
                .task { await model.loadEverything() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 860, height: 620)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra("Macarchy", systemImage: "circle.lefthalf.filled") {
            MenuBarContent()
                .environment(model)
        }
    }
}
