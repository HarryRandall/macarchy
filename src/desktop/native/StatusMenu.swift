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

        // Also reachable when ⌘⌃Space belongs to another app or the system.
        Button("Theme Switcher…") {
            Task { await ThemeSwitcher.shared.show() }
        }
        .keyboardShortcut(" ", modifiers: [.command, .control])

        Button("Settings…") { AppDelegate.showMainWindow() }
            .keyboardShortcut(",", modifiers: .command)

        Button("Restart All Daemons") {
            Task { await model.daemons.restartAll() }
        }

        Divider()

        Button("Quit Macarchy") { AppDelegate.quit() }
            .keyboardShortcut("q", modifiers: .command)
    }
}
