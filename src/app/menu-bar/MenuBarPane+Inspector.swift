import Macarchy
import SwiftUI

extension MenuBarPane {
    @ViewBuilder
    var inspector: some View {
        if bar.selectedComponents.count > 1 {
            SettingsCard("\(bar.selectedComponents.count) components selected") {
                SettingRow("Move selected") {
                    Button("Left") { moveSelection(to: "left") }
                    Button("Right") { moveSelection(to: "right") }
                }
                SettingRow("Visibility") {
                    Button("Show all") { bar.updateSelection { $0.visible = true } }
                    Button("Hide all") { bar.updateSelection { $0.visible = false } }
                }
                selectionSpacing
            }.disabled(bar.isApplying || bar.isHydrating)
        } else if let component = bar.selectedComponent {
            SettingsCard(
                component.title,
                footnote: component.isCustom
                    ? "This component is saved with your menu bar. Text is displayed literally, never run as a command."
                    : "The original widget supplies its live readings. Edit the group here without replacing its data source."
            ) {
                SettingRow("Visible") {
                    Toggle("Visible", isOn: componentBinding(component, \.visible)).labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingRow("Side") {
                    SegmentedPill(
                        selection: Binding(
                            get: { component.side }, set: { bar.moveToSide(component.id, side: $0) }
                        ),
                        options: [.init("left", "Left"), .init("right", "Right")])
                }
                selectionSpacing
                if component.isCustom {
                    customFields(component)
                    SettingRow("Remove component") {
                        Button("Remove", role: .destructive) { bar.removeCustom(component.id) }
                    }
                } else {
                    SettingRow(
                        "Contents",
                        detail: component.id == "workspaces"
                            ? "All workspaces, including those created later"
                            : "\(component.members.count) linked items"
                    ) {
                        Label("Live widget", systemImage: "waveform.path").font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(bar.isApplying || bar.isHydrating)
        } else {
            SettingsCard {
                Text("Select a component above to edit it.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(24)
            }
        }
    }

    private func moveSelection(to side: String) {
        if let id = bar.selection.first { bar.moveToSide(id, side: side) }
    }

    @ViewBuilder
    private var selectionSpacing: some View {
        SettingRow("Padding", detail: spacingDetail(padding: true)) {
            ValueSlider(
                value: selectionSpacingBinding(padding: true), range: 0...24, unit: "pt"
            ) { _ in }
        }
        SettingRow("Gap", detail: spacingDetail(padding: false)) {
            ValueSlider(
                value: selectionSpacingBinding(padding: false), range: 0...40, unit: "pt"
            ) { _ in }
        }
        SettingRow("Spacing presets") {
            Button("Compact") {
                bar.updateSelection {
                    $0.paddingOverride = 2; $0.spacingOverride = 4
                }
            }
            Button("Use bar defaults") {
                bar.updateSelection {
                    $0.paddingOverride = nil; $0.spacingOverride = nil
                }
            }
        }
    }

    private func spacingDetail(padding: Bool) -> String {
        let values = bar.selectedComponents.map {
            padding ? bar.draft.padding(for: $0) : bar.draft.spacing(for: $0)
        }
        if Set(values).count > 1 { return "Mixed values. Adjust to set all selected." }
        return padding ? "Inside the selected groups" : "After each selected group"
    }

    private func selectionSpacingBinding(padding: Bool) -> Binding<Double> {
        Binding(
            get: {
                guard let component = bar.selectedComponents.first else { return 0 }
                return padding
                    ? bar.draft.padding(for: component) : bar.draft.spacing(for: component)
            },
            set: { value in
                bar.updateSelection {
                    if padding { $0.paddingOverride = value } else { $0.spacingOverride = value }
                }
            })
    }

    @ViewBuilder
    private func customFields(_ component: BarComponent) -> some View {
        SettingRow("Name") {
            TextField("Name", text: componentBinding(component, \.title))
                .textFieldStyle(.roundedBorder).frame(width: 200)
        }
        if component.kind == "spacer" {
            SettingRow("Width") {
                ValueSlider(
                    value: componentBinding(component, \.customWidth), range: 4...120, step: 1,
                    unit: "pt"
                ) { _ in }
            }
        } else {
            SettingRow("Icon", detail: "A character or symbol") {
                TextField("★", text: componentBinding(component, \.icon))
                    .textFieldStyle(.roundedBorder).frame(width: 200)
            }
            SettingRow("Text") {
                TextField("Label", text: componentBinding(component, \.text))
                    .textFieldStyle(.roundedBorder).frame(width: 200)
            }
            SettingRow("Colour") {
                ColorWell(
                    color: Binding(
                        get: { Color(macarchyHex: component.colour) ?? .white },
                        set: { colour in
                            bar.update(component.id) { $0.colour = colour.macarchyString(.argb) }
                        }
                    ), format: .argb
                ) { _ in }
            }
        }
    }

    private func componentBinding<Value>(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                bar.draft.components.first { $0.id == component.id }?[keyPath: key]
                    ?? component[keyPath: key]
            },
            set: { new in bar.update(component.id) { $0[keyPath: key] = new } })
    }

    var geometryCard: some View {
        SettingsCard(
            "Bar appearance",
            footnote:
                "These settings apply to the whole bar. Component scripts and live data stay connected."
        ) {
            SettingRow("Default padding", detail: "For groups without an override") {
                ValueSlider(
                    value: Binding(
                        get: { bar.draft.padding },
                        set: { value in
                            bar.edit { $0.componentPadding = value }
                        }), range: 0...24, unit: "pt"
                ) { _ in }
            }
            SettingRow("Default gap", detail: "For groups without an override") {
                ValueSlider(
                    value: Binding(
                        get: { bar.draft.spacing },
                        set: { value in
                            bar.edit { $0.componentSpacing = value }
                        }), range: 0...40, unit: "pt"
                ) { _ in }
            }
            geometrySlider("Height", key: "height", range: 20...60)
            SettingRow("Position") {
                SegmentedPill(
                    selection: geometryBinding("position", fallback: "top"),
                    options: [.init("top", "Top"), .init("bottom", "Bottom")])
            }
            geometrySlider("Left padding", key: "padding_left", range: 0...60)
            geometrySlider("Right padding", key: "padding_right", range: 0...60)
            geometrySlider("Corner radius", key: "corner_radius", range: 0...20)
            geometrySlider("Vertical offset", key: "y_offset", range: -20...20)
            geometrySlider("Blur", key: "blur_radius", range: 0...50)
            SettingRow("All Spaces") {
                Toggle(
                    "All Spaces",
                    isOn: Binding(
                        get: { bar.draft.geometry["sticky"] == "on" },
                        set: { value in bar.edit { $0.geometry["sticky"] = value ? "on" : "off" } }
                    )
                ).toggleStyle(.switch).labelsHidden()
            }
        }.disabled(bar.isApplying || bar.isHydrating)
    }

    private func geometrySlider(
        _ title: String, key: String, range: ClosedRange<Double>
    ) -> some View {
        SettingRow(title) {
            ValueSlider(
                value: Binding(
                    get: { Double(bar.draft.geometry[key] ?? "0") ?? 0 },
                    set: { value in bar.edit { $0.geometry[key] = String(Int(value)) } }
                ), range: range, unit: "pt"
            ) { _ in }
        }
    }

    private func geometryBinding(_ key: String, fallback: String) -> Binding<String> {
        Binding(
            get: { bar.draft.geometry[key] ?? fallback },
            set: { value in bar.edit { $0.geometry[key] = value } })
    }
}
