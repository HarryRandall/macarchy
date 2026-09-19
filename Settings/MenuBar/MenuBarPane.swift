import SwiftUI
import Desktop

struct MenuBarPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var bar = model.menuBar

        Form {
            Section {
                MenuBarStrip(
                    height: bar.height,
                    paddingLeft: bar.paddingLeft,
                    paddingRight: bar.paddingRight,
                    cornerRadius: bar.cornerRadius,
                    position: bar.position,
                    groups: bar.groups,
                    palette: model.currentThemePalette
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } header: {
                Text("Preview")
            }

            Section {
                slider("Height", value: $bar.height, range: 16...60, key: "height")
                Picker("Position", selection: $bar.position) {
                    Text("Top").tag("top")
                    Text("Bottom").tag("bottom")
                }
                .onChange(of: bar.position) { _, new in bar.applyBar("position", new) }

                slider("Padding left", value: $bar.paddingLeft, range: 0...60, key: "padding_left")
                slider(
                    "Padding right", value: $bar.paddingRight, range: 0...60, key: "padding_right")
                slider(
                    "Corner radius", value: $bar.cornerRadius, range: 0...20, key: "corner_radius")
                slider("Vertical offset", value: $bar.yOffset, range: -20...20, key: "y_offset")
                slider("Blur", value: $bar.blurRadius, range: 0...50, key: "blur_radius")

                Toggle("Stay visible in fullscreen", isOn: $bar.sticky)
                    .onChange(of: bar.sticky) { _, new in bar.applyBar("sticky", new ? "on" : "off")
                    }
            } header: {
                Text("Bar")
            } footer: {
                Text(
                    "Hydrated from sketchybar --query bar, so these are the values actually running."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                if bar.groups.isEmpty {
                    Text("No items found. Is sketchybar running?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bar.groups) { group in
                        LabeledContent {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { group.visible },
                                    set: { bar.setGroup(group, visible: $0) }
                                )
                            )
                            .labelsHidden()
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.id)
                                Text(describe(group))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text(
                    "Items · \(bar.groups.count) sources, \(bar.groups.reduce(0) { $0 + $1.items.count }) live"
                )
            } footer: {
                Text(
                    "Grouped by the script that declares them — spaces.sh alone produces eleven items. Toggling hides them; it never edits the script."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Reload SketchyBar") { bar.reloadSketchybar() }
                    Spacer()
                    Button("Open config") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [Paths.home.appending(path: ".config/sketchybar")])
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await model.menuBar.hydrate() }
    }

    private func describe(_ group: MenuBarModel.ItemGroup) -> String {
        let count = group.items.count
        if count == 1 { return group.items[0] }
        return "\(count) items · " + group.items.prefix(3).joined(separator: ", ")
            + (count > 3 ? "…" : "")
    }

    @ViewBuilder
    private func slider(
        _ label: String, value: Binding<Double>,
        range: ClosedRange<Double>, key: String
    ) -> some View {
        @Bindable var bar = model.menuBar
        LabeledContent(label) {
            HStack {
                Slider(value: value, in: range, step: 1)
                    .frame(width: 150)
                    .onChange(of: value.wrappedValue) { _, new in
                        bar.applyBar(key, String(Int(new)))
                    }
                Text("\(Int(value.wrappedValue))")
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
}

/// A scaled stand-in for the bar, so geometry changes are legible without
/// looking away from the window.
private struct MenuBarStrip: View {
    let height: Double
    let paddingLeft: Double
    let paddingRight: Double
    let cornerRadius: Double
    let position: String
    let groups: [MenuBarModel.ItemGroup]
    let palette: GhosttyPalette?

    var body: some View {
        VStack(spacing: 0) {
            if position == "bottom" { Spacer(minLength: 0) }

            HStack(spacing: 10) {
                ForEach(groups.filter(\.visible).prefix(5)) { group in
                    Text(group.id)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette?.foreground ?? .primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (palette?.brightBlack ?? .secondary).opacity(0.25),
                            in: RoundedRectangle(cornerRadius: 3))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, paddingLeft / 2)
            .padding(.trailing, paddingRight / 2)
            .frame(height: max(height, 14))
            .background(palette?.background.opacity(0.75) ?? Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            if position == "top" { Spacer(minLength: 0) }
        }
        .frame(height: 72)
        .padding(6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }
}
