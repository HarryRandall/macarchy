import SwiftUI
import Desktop

extension BordersPane {
    private var activeTheme: InstalledTheme? {
        model.themes.themes.first { $0.name == model.themes.current }
    }

    private var defaultTheme: Theme? {
        guard let theme = activeTheme else { return nil }
        return ThemeCatalog.bundledDefault(named: theme.name)
    }

    private var coloursModified: Bool {
        guard let original = defaultTheme, let current = activeTheme?.manifest else { return false }
        return current.colors.borderActive != original.colors.borderActive
            || current.colors.borderInactive != original.colors.borderInactive
    }

    func colourCard() -> some View {
        SettingsCard(
            "Colour",
            footnote: "These colours are saved to the active theme and shared with Themes. "
                + "Click a swatch to edit its colour, opacity or hex value. "
                + "Reset restores only this theme's original border colours, when available.",
            reset: resetColours,
            resetEnabled: coloursModified
        ) {
            borderColourRow("Active", detail: "The window with focus", key: \.borderActive)
            borderColourRow("Inactive", detail: "Every other window", key: \.borderInactive)
        }
        .disabled(activeTheme?.manifest == nil)
    }

    private func borderColourRow(
        _ title: String, detail: String, key: WritableKeyPath<Theme.Colors, String?>
    ) -> some View {
        let raw = activeTheme?.manifest?.colors[keyPath: key]
        return SettingRow(title, detail: detail) {
            ColorWell(
                color: Binding(
                    get: {
                        Color(macarchyHex: activeTheme?.manifest?.colors[keyPath: key]) ?? .clear
                    },
                    set: { colour in
                        guard let encoded = colour.macarchyString(.argb),
                            var manifest = activeTheme?.manifest
                        else { return }
                        manifest.colors[keyPath: key] = encoded
                        saveBorderColours(manifest)
                    }
                ),
                format: .argb,
                isUnset: raw == nil
            ) { _ in }
            .accessibilityLabel("\(title) border colour")
            .help("Edit \(title.lowercased()) border colour")
        }
    }

    private func resetColours() {
        guard let original = defaultTheme, var manifest = activeTheme?.manifest else { return }
        manifest.colors.borderActive = original.colors.borderActive
        manifest.colors.borderInactive = original.colors.borderInactive
        saveBorderColours(manifest)
    }

    private func saveBorderColours(_ manifest: Theme) {
        guard let theme = activeTheme else { return }
        do {
            try model.themes.save(manifest, to: theme.directory)
            model.borders.applyBorders()
        } catch {
            colourError = error.localizedDescription
        }
    }
}
