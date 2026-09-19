import SwiftUI
import Kit

/// The theme.json editor rows. Split out of ThemesPane, which was doing
/// grid, background picker, editor and actions in one type.
extension ThemesPane {
    @ViewBuilder
    func editorSection(_ theme: Theme) -> some View {
        Section("\(theme.name) · theme.json") {
            Toggle("Dark mode", isOn: binding(\.dark))

            colorRow("Border active", \.colors.borderActive, .argb, theme)
            colorRow("Border inactive", \.colors.borderInactive, .argb, theme)
            colorRow("Menu bar background", \.colors.sketchybarBar, .argb, theme)
            colorRow("Menu bar text", \.colors.sketchybarText, .argb, theme)
            colorRow("Firefox accent", \.colors.firefoxAccent, .rgb, theme)

            LabeledContent("Neovim colorscheme") {
                TextField(
                    "",
                    text: Binding(
                        get: { draft?.apps.nvimColorscheme ?? "" },
                        set: { newValue in
                            guard var edited = draft else { return }
                            edited.apps.nvimColorscheme = newValue.isEmpty ? nil : newValue
                            draft = edited
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit { if let draft { save(draft, to: theme) } }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ThemeManifest, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard var edited = draft, let theme else { return }
                edited[keyPath: keyPath] = newValue
                draft = edited
                save(edited, to: theme)
            }
        )
    }

    @ViewBuilder
    private func colorRow(
        _ label: String,
        _ keyPath: WritableKeyPath<ThemeManifest, String?>,
        _ format: Color.MacarchyFormat,
        _ theme: Theme
    ) -> some View {
        let raw = draft?[keyPath: keyPath]
        LabeledContent(label) {
            HStack(spacing: 8) {
                Text(raw ?? "not set")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(raw == nil ? .tertiary : .secondary)
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { Color(macarchyHex: raw) ?? .clear },
                        set: { newValue in
                            guard var edited = draft, let encoded = newValue.macarchyString(format)
                            else { return }
                            edited[keyPath: keyPath] = encoded
                            draft = edited
                            save(edited, to: theme)
                        }
                    ), supportsOpacity: format == .argb
                )
                .labelsHidden()
            }
        }
    }

}
