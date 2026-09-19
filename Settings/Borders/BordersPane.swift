import SwiftUI
import AppKit

struct BordersPane: View {
    @Environment(AppModel.self) var model
    @State var colourError: String?
    @State private var newExclusion = ""

    var body: some View {
        @Bindable var borders = model.borders

        SettingsPage("Borders", subtitle: "The outline drawn around the focused window") {
            previewCard(borders)
            colourCard()
            geometryCard(borders)
            cornersCard(borders)
            exclusionsCard(borders)
        }
        .task { await borders.hydrate() }
        .alert(
            "Could not save colour",
            isPresented: Binding(
                get: { colourError != nil }, set: { if !$0 { colourError = nil } }
            )
        ) {
            Button("OK") { colourError = nil }
        } message: {
            Text(colourError ?? "")
        }
    }

    // MARK: - Preview

    private func previewCard(_ borders: BordersModel) -> some View {
        SettingsCard {
            BorderPreview(
                width: borders.width,
                cornerRadius: borders.cornerRadius,
                appliedCornerRadius: borders.cornerRadiusApplied,
                activeColor: Color(macarchyHex: model.currentThemeValue("BORDER_ACTIVE"))
                    ?? .accentColor,
                wallpaper: model.currentThemeWallpaper,
                visible: borders.visible
            )
            .padding(12)
        }
    }

    // MARK: - Geometry

    private func geometryCard(_ borders: BordersModel) -> some View {
        @Bindable var borders = borders
        return SettingsCard(
            "Geometry",
            footnote: """
                borders has no query API, so these are read from settings.env \
                rather than the daemon.
                """,
            reset: resetGeometry,
            resetEnabled: borders.width != 6 || !borders.visible
        ) {
            SettingRow("Show borders", detail: "Outline the window that has focus") {
                Toggle("", isOn: $borders.visible)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: borders.visible) { _, _ in borders.applyBorders() }
            }

            SettingRow("Width", detail: "Thickness of the outline in points") {
                ValueSlider(
                    value: $borders.width,
                    range: 0...16,
                    step: 0.5,
                    decimals: 1,
                    unit: "pt"
                ) { _ in borders.applyBorders() }
            }
            .disabled(!borders.visible)
            .opacity(borders.visible ? 1 : 0.45)
        }
    }

    // MARK: - Corners

    private func cornersCard(_ borders: BordersModel) -> some View {
        @Bindable var borders = borders
        let isSquare = borders.cornerRadius < BordersModel.squareThreshold
        return SettingsCard(
            "Corners", footnote: cornersFootnote,
            reset: resetCorners,
            resetEnabled: borders.hasCornerRadiusOverride
        ) {
            SettingRow(
                "Corner radius",
                detail: isSquare
                    ? "Square corners"
                    : "The border follows the window's own radius"
            ) {
                ValueSlider(
                    value: $borders.cornerRadius,
                    range: BordersModel.cornerRadiusRange,
                    step: 0.1,
                    decimals: 1,
                    unit: "pt"
                ) { _ in borders.applyCornerRadius() }
            }

        }
    }

    private var cornersFootnote: String {
        "Changes apply to newly opened windows. Relaunch an app to see them. "
            + "Native macOS windows support this setting; Firefox and Chromium apps use their own "
            + "corners. The border follows the window. Reset restores the macOS default."
    }

    // MARK: - Exclusions

    private func exclusionsCard(_ borders: BordersModel) -> some View {
        SettingsCard(
            "Excluded apps",
            footnote:
                "Windows belonging to these apps are never outlined. iPhone Mirroring is always excluded.",
            reset: resetExclusions,
            resetEnabled: borders.excludedApps.contains { $0 != "iPhone Mirroring" }
        ) {
            ForEach(borders.excludedApps, id: \.self) { app in
                SettingRow(app) {
                    Button {
                        borders.excludedApps.removeAll { $0 == app }
                        borders.applyBorders()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Stop excluding \(app)")
                }
            }

            addExclusionRow(borders)
        }
    }

    private func addExclusionRow(_ borders: BordersModel) -> some View {
        HStack(spacing: 8) {
            TextField("Application name", text: $newExclusion)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addExclusion(borders) }
            Button("Add") { addExclusion(borders) }
                .disabled(trimmedExclusion.isEmpty)
        }
        .padding(.horizontal, CardMetrics.horizontalPadding)
        .padding(.vertical, 10)
    }

    private var trimmedExclusion: String {
        newExclusion.trimmingCharacters(in: .whitespaces)
    }

    private func addExclusion(_ borders: BordersModel) {
        let trimmed = trimmedExclusion
        guard !trimmed.isEmpty, !borders.excludedApps.contains(trimmed) else { return }
        borders.excludedApps.append(trimmed)
        newExclusion = ""
        borders.applyBorders()
    }

    private func resetGeometry() {
        model.borders.width = 6
        model.borders.visible = true
        model.borders.applyBorders()
    }

    private func resetCorners() {
        Task { await model.borders.resetCornerRadius() }
    }

    private func resetExclusions() {
        model.borders.excludedApps = ["iPhone Mirroring"]
        model.borders.applyBorders()
    }

}
