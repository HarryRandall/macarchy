import SwiftUI
import Desktop

struct BordersPane: View {
    @Environment(AppModel.self) var model
    @State private var newExclusion = ""
    var editor: BordersEditor { model.bordersEditor }

    var body: some View {
        SettingsPage("Borders", subtitle: "The outline drawn around the focused window") {
            previewCard()
            VStack(spacing: 18) {
                colourCard()
                geometryCard()
                cornersCard()
                exclusionsCard()
            }
            .disabled(editor.isApplying || !editor.loaded)
        }
        .task(id: model.themes.current) {
            guard !editor.hasChanges, !editor.isApplying else { return }
            await model.borders.hydrate()
            guard !editor.hasChanges, !editor.isApplying else { return }
            editor.load(model.borders.appearance(theme: activeTheme))
        }
        .onChange(of: editor.draft) { _, _ in editor.changed() }
        .onChange(of: model.themes.current) { _, _ in
            editor.load(model.borders.appearance(theme: activeTheme))
        }
    }

    private func geometryCard() -> some View {
        @Bindable var editor = editor
        return SettingsCard(
            "Geometry",
            footnote: "Width is measured in points. Changes affect all outlined windows.",
            reset: resetGeometry,
            resetEnabled: editor.draft.width != 6 || !editor.draft.visible,
            resetLabel: "Reset",
            resetHelp: "Restore 6 pt width and turn borders on. Colours and corners stay unchanged."
        ) {
            SettingRow("Show borders", detail: "Outline the window that has focus") {
                Toggle("Show borders", isOn: $editor.draft.visible)
                    .labelsHidden().toggleStyle(.switch)
            }
            SettingRow("Width", detail: "Thickness of the outline") {
                ValueSlider(
                    value: $editor.draft.width, range: 0...16, step: 0.5, decimals: 1, unit: "pt"
                ) { _ in }
            }
            .disabled(!editor.draft.visible)
        }
    }

    private func cornersCard() -> some View {
        @Bindable var editor = editor
        return SettingsCard(
            "Corners",
            footnote:
                "Square uses the smallest supported radius (0.3 pt). Rounded is 8 pt. "
                + "Default removes the override and lets macOS choose. Drag the slider for a custom radius. Firefox and Chromium apps "
                + "keep their own corners. The preview is illustrative.",
            reset: resetCorners,
            resetEnabled: editor.draft.radius != nil,
            resetLabel: "Use default",
            resetHelp: "Remove the custom corner radius. macOS will choose corners for new windows."
        ) {
            SettingRow("Shape") {
                SegmentedPill(
                    selection: presetBinding,
                    options: [
                        .init("system", "Default"), .init("square", "Square"),
                        .init("rounded", "Rounded")
                    ])
            }
            SettingRow(
                "Corner radius",
                detail: radiusDescription
            ) {
                if editor.draft.radius != nil {
                    ValueSlider(
                        value: radiusBinding, range: BordersModel.cornerRadiusRange,
                        step: 0.1, decimals: 1, unit: "pt"
                    ) { _ in }
                } else {
                    Text("System default").font(.callout).foregroundStyle(.secondary)
                }
            }
            Text("Corner changes affect newly opened windows. Relaunch an app to see them.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }

    private var radiusDescription: String {
        switch editor.draft.radius {
        case nil: "Managed by macOS"
        case 0.3: "Square preset"
        case 8: "Rounded preset"
        default: "Custom radius"
        }
    }

    private var radiusBinding: Binding<Double> {
        Binding(get: { editor.draft.previewRadius }, set: { editor.draft.radius = $0 })
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: {
                switch editor.draft.radius {
                case nil: "system"
                case 0.3: "square"
                case 8: "rounded"
                default: "custom"
                }
            },
            set: { preset in
                switch preset {
                case "system": editor.draft.radius = nil
                case "square": editor.draft.radius = 0.3
                case "rounded": editor.draft.radius = 8
                default: break
                }
            })
    }

    private func exclusionsCard() -> some View {
        SettingsCard(
            "Excluded apps",
            footnote: "These apps are never outlined. iPhone Mirroring is always excluded.",
            reset: resetExclusions,
            resetEnabled: editor.draft.excludedApps.contains { $0 != "iPhone Mirroring" },
            resetLabel: "Clear custom",
            resetHelp: "Remove your exclusions, keeping iPhone Mirroring excluded."
        ) {
            ForEach(editor.draft.excludedApps, id: \.self) { app in
                SettingRow(app) {
                    if app == "iPhone Mirroring" {
                        Text("Always excluded").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button {
                            editor.draft.excludedApps.removeAll { $0 == app }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain).help("Stop excluding \(app)")
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Application name", text: $newExclusion)
                    .textFieldStyle(.roundedBorder).onSubmit(addExclusion)
                Button("Add", action: addExclusion)
                    .disabled(newExclusion.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(12)
        }
    }

    private func addExclusion() {
        let name = newExclusion.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !editor.draft.excludedApps.contains(name) else { return }
        editor.draft.excludedApps.append(name)
        newExclusion = ""
    }

    private func resetGeometry() { editor.draft.width = 6; editor.draft.visible = true }
    private func resetCorners() { editor.draft.radius = nil }
    private func resetExclusions() { editor.draft.excludedApps = ["iPhone Mirroring"] }
}
