import SwiftUI
import AppKit

struct BordersPane: View {
    @Environment(AppModel.self) private var model
    @State private var newExclusion = ""

    var body: some View {
        @Bindable var borders = model.borders

        Form {
            Section("Preview") {
                BorderPreview(
                    width: borders.width,
                    cornerRadius: borders.cornerRadius,
                    appliedCornerRadius: borders.cornerRadiusApplied,
                    activeColor: Color(macarchyHex: model.currentThemeValue("BORDER_ACTIVE")) ?? .accentColor,
                    wallpaper: model.currentThemeWallpaper,
                    visible: borders.visible
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            }

            Section {
                Toggle("Show borders", isOn: $borders.visible)
                    .onChange(of: borders.visible) { _, _ in borders.applyBorders() }

                LabeledContent("Width") {
                    HStack {
                        Slider(value: $borders.width, in: 0...16, step: 0.5)
                            .frame(width: 160)
                            .onChange(of: borders.width) { _, _ in borders.applyBorders() }
                        Text(String(format: "%.1f", borders.width))
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .disabled(!borders.visible)

            } header: {
                Text("Geometry")
            } footer: {
                Text("borders has no query API, so these are read from settings.env rather than the daemon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded apps") {
                ForEach(borders.blacklist, id: \.self) { app in
                    HStack {
                        Text(app)
                        Spacer()
                        Button {
                            borders.blacklist.removeAll { $0 == app }
                            borders.applyBorders()
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Application name", text: $newExclusion)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let trimmed = newExclusion.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !borders.blacklist.contains(trimmed) else { return }
                        borders.blacklist.append(trimmed)
                        newExclusion = ""
                        borders.applyBorders()
                    }
                    .disabled(newExclusion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            cornerRadiusSection(borders)

            Section("Colour") {
                LabeledContent("Active") { readOnlyColour(model.currentThemeValue("BORDER_ACTIVE")) }
                LabeledContent("Inactive") { readOnlyColour(model.currentThemeValue("BORDER_INACTIVE")) }
            }
            Section {
                Button("Edit in Themes") { model.selection = .themes }
            } footer: {
                Text("Colour belongs to the active theme; geometry belongs here. No key lives in both files, so neither can override the other.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await borders.hydrate() }
    }

    @ViewBuilder
    private func cornerRadiusSection(_ borders: BordersModel) -> some View {
        Section {
            LabeledContent("Corner radius") {
                HStack {
                    Slider(value: Binding(
                        get: { borders.cornerRadius },
                        set: { borders.cornerRadius = $0 }
                    ), in: BordersModel.cornerRadiusRange)
                    .frame(width: 160)
                    .onChange(of: borders.cornerRadius) { _, _ in borders.applyCornerRadius() }
                    Text(borders.cornerRadius < BordersModel.squareThreshold
                         ? "Square"
                         : String(format: "%.1f", borders.cornerRadius))
                        .monospacedDigit()
                        .frame(width: 54, alignment: .trailing)
                }
            }

            HStack {
                Button("Reset to system default") { Task { await borders.resetCornerRadius() } }
                Spacer()
            }

            if borders.cornerRadiusNeedsRestart {
                Label("Applies to windows opened from now on. Relaunch an app to see it.",
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        } header: {
            Text("Corners")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sets the window corner radius and shapes the border to match — the border always follows the window rather than being set separately.")
                Text("Global, not per-app. Only native AppKit windows honour NSConvolutionOverride1; Chromium apps and Firefox keep their own corners, and the border tracks those instead.")
                Text("Takes effect for newly opened windows; already-open windows keep the radius they were created with. Values at or below 0.25 are ignored, so the slider bottoms out at Square.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func readOnlyColour(_ value: String?) -> some View {
        HStack(spacing: 7) {
            Text(value ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            if let color = Color(macarchyHex: value) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.separator))
            }
        }
    }
}
