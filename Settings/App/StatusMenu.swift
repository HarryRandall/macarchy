import SwiftUI
import Desktop

/// The menu bar surface that retires the Raycast theme-switcher extension.
struct StatusMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(model.themes.themes) { theme in
            Button {
                Task { await model.themes.apply(theme) }
            } label: {
                if theme.name == model.themes.current {
                    Label(theme.name, systemImage: "checkmark")
                } else {
                    Text(theme.name)
                }
            }
        }

        Divider()

        Button("Settings…") { openWindow(id: "main") }
            .keyboardShortcut(",", modifiers: .command)

        Button("Restart All Daemons") {
            Task {
                for daemon in Daemon.allCases { await model.daemons.restart(daemon) }
            }
        }

        Divider()

        Button("Quit Macarchy Settings") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
