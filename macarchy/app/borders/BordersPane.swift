import SwiftUI
import Macarchy
import AppKit

struct BordersPane: View {
    @Environment(AppModel.self) var model
    var editor: BordersEditor { model.bordersEditor }

    var body: some View {
        SettingsPage("Borders", subtitle: "The outline drawn around the focused window.") {
            LazyVStack(spacing: Metrics.cardGap, pinnedViews: editor.live ? [] : [.sectionHeaders])
            {
                Section {
                    VStack(spacing: Metrics.cardGap) {
                        colourCard()
                        geometryCard()
                        cornersCard()
                        exclusionsCard()
                    }
                    .disabled(editor.isApplying || !editor.loaded)
                } header: {
                    previewHeader()
                }
            }
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
            help:
                "Width applies to every outlined window.",
            reset: resetGeometry,
            resetEnabled: editor.draft.width != 6 || !editor.draft.visible,
            resetLabel: "Reset",
            resetHelp: "Restore 6 pt width and turn borders on"
        ) {
            SettingRow("Show borders", help: "Outline the window that has focus") {
                Toggle("Show borders", isOn: $editor.draft.visible)
                    .labelsHidden().toggleStyle(.switch)
            }
            SettingRow("Width", help: "Thickness of the outline") {
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
            help:
                "Corner changes affect newly opened windows. Relaunch an app to see them.",
            reset: resetCorners,
            resetEnabled: editor.draft.radius != nil,
            resetLabel: "Use default",
            resetHelp: "Let macOS choose corners for new windows"
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
            help:
                "These apps are never outlined. Add or remove apps to choose which windows have borders.",
            reset: resetExclusions,
            resetEnabled: !editor.draft.excludedApps.isEmpty,
            resetLabel: "Clear all",
            resetHelp: "Remove all exclusions"
        ) {
            ForEach(editor.draft.excludedApps, id: \.self) { app in
                SettingRow(app) {
                    AppIcon(name: app)
                } accessory: {
                    Button {
                        editor.draft.excludedApps.removeAll { $0 == app }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHelp("Stop excluding \(app)")
                    .accessibilityLabel("Stop excluding \(app)")
                }
            }
            HStack {
                Button("Add Application…", action: pickExcludedApp)
                    .hoverHelp("Never outline this app")
                Spacer()
            }
            .padding(.horizontal, CardMetrics.horizontalPadding)
            .padding(.vertical, Metrics.medium)
        }
    }

    private func pickExcludedApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        panel.message = "Choose an application that should have no window borders"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        guard !editor.draft.excludedApps.contains(name) else { return }
        editor.draft.excludedApps.append(name)
    }

    private func resetGeometry() { editor.draft.width = 6; editor.draft.visible = true }
    private func resetCorners() { editor.draft.radius = nil }
    private func resetExclusions() { editor.draft.excludedApps = [] }
}
