import SwiftUI
import Macarchy

extension BordersPane {
    var activeTheme: InstalledTheme? {
        model.themes.themes.first { $0.name == model.themes.current }
    }

    private var defaultTheme: Theme? {
        guard let theme = activeTheme else { return nil }
        return ThemeCatalog.bundledDefault(named: theme.name)
    }

    private var coloursModified: Bool {
        guard let original = defaultTheme else { return false }
        return editor.draft.activeColour != original.colors.borderActive
            || editor.draft.inactiveColour != original.colors.borderInactive
    }

    func colourCard() -> some View {
        SettingsCard(
            "Colour",
            help: "Edit colour, opacity or hex values. Apply saves them to the active theme.",
            reset: resetColours,
            resetEnabled: coloursModified,
            resetLabel: "Theme colours",
            resetHelp: "Restore this theme's original border colours"
        ) {
            borderColourRow("Active", detail: "The window with focus", key: \.activeColour)
            borderColourRow("Inactive", detail: "Every other window", key: \.inactiveColour)
        }
        .disabled(activeTheme?.manifest == nil)
    }

    private func borderColourRow(
        _ title: String, detail: String, key: WritableKeyPath<BorderAppearance, String?>
    ) -> some View {
        SettingRow(title, help: detail) {
            ColorWell(
                color: Binding(
                    get: { Color(macarchyHex: editor.draft[keyPath: key]) ?? .clear },
                    set: { editor.draft[keyPath: key] = $0.macarchyString(.argb) }
                ),
                format: .argb,
                isUnset: editor.draft[keyPath: key] == nil
            ) { _ in }
            .accessibilityLabel("\(title) border colour")
            .hoverHelp("Edit \(title.lowercased()) border colour")
        }
    }

    private func resetColours() {
        guard let original = defaultTheme else { return }
        editor.draft.activeColour = original.colors.borderActive
        editor.draft.inactiveColour = original.colors.borderInactive
    }
}
