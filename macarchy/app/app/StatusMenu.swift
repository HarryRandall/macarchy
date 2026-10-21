import SwiftUI
import Macarchy

/// The status item menu: theme switching and quick actions.
struct StatusMenu: View {
    @Environment(AppModel.self) private var model

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

        Button("Settings…") { AppDelegate.showMainWindow() }
            .keyboardShortcut(",", modifiers: .command)

        Button("Restart All Daemons") {
            Task {
                for daemon in Daemon.allCases { await model.daemons.restart(daemon) }
            }
        }

        Divider()

        Button("Quit Macarchy") { AppDelegate.quit() }
            .keyboardShortcut("q", modifiers: .command)
    }
}
