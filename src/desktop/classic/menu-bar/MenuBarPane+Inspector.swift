import Macarchy
import SwiftUI

extension MenuBarPane {
    /// A summary of what is selected, with the way into the full editor.
    ///
    /// The old inspector grew a long form down the page underneath the bar it
    /// was editing, so the thing you were changing scrolled out of sight while
    /// you changed it. Everything moved into `ComponentEditor`.
    @ViewBuilder
    var inspector: some View {
        if bar.selectedComponents.count > 1 {
            SettingsCard("\(bar.selectedComponents.count) components selected") {
                SettingRow("Move selected") {
                    HStack(spacing: Metrics.small) {
                        Button("Left") { moveSelection(to: "left") }
                        Button("Centre") { moveSelection(to: "center") }
                        Button("Right") { moveSelection(to: "right") }
                    }
                }
                SettingRow("Visibility") {
                    HStack(spacing: Metrics.small) {
                        Button("Show all") { bar.updateSelection { $0.visible = true } }
                        Button("Hide all") { bar.updateSelection { $0.visible = false } }
                    }
                }
                selectionSpacing
            }
            .disabled(bar.isApplying || bar.isHydrating)
        } else if let component = bar.selectedComponent {
            SettingsCard("Selected") {
                SettingRow(
                    component.title,
                    help: component.isCustom
                        ? "Edit text, icons, colours and spacing."
                        : "\(component.members.count) linked items supplying live readings."
                ) {
                    Text(
                        component.isCustom
                            ? component.rendered(component.text) : "Edit presentation"
                    )
                    .font(.meta)
                    .padding(.horizontal, Metrics.small)
                    .padding(.vertical, Metrics.xs)
                    .background(
                        Color(macarchyHex: bar.colour) ?? .black,
                        in: RoundedRectangle(
                            cornerRadius: Metrics.radiusSmall, style: .continuous))
                } accessory: {
                    HStack(spacing: Metrics.small) {
                        Toggle("Visible", isOn: componentBinding(component, \.visible))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        Button("Edit…") { presentEditor(component) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .disabled(bar.isApplying || bar.isHydrating)
        } else {
            SettingsCard {
                Text("Select a component above to edit it.")
                    .font(.rowTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(Metrics.xxl)
            }
        }
    }

    /// Opens the full editor for one component.
    func presentEditor(_ component: BarComponent) {
        bar.select(component.id)
        model.modal.present {
            ComponentEditor(componentID: component.id) { model.modal.dismiss() }
        }
    }

    private func moveSelection(to side: String) {
        if let id = bar.selection.first { bar.moveToSide(id, side: side) }
    }

    @ViewBuilder
    private var selectionSpacing: some View {
        SettingRow(
            "Padding", detail: spacingStatus(padding: true),
            help: "Space inside each selected group"
        ) {
            ValueSlider(
                value: selectionSpacingBinding(padding: true), range: 0...24, unit: "pt"
            ) { _ in }
        }
        SettingRow(
            "Gap", detail: spacingStatus(padding: false), help: "Space after each selected group"
        ) {
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

    private func spacingStatus(padding: Bool) -> String? {
        let values = bar.selectedComponents.map {
            padding ? bar.draft.padding(for: $0) : bar.draft.spacing(for: $0)
        }
        return Set(values).count > 1 ? "Mixed values" : nil
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

    /// The studio: the component at each of its sample readings, then every
    func componentBinding<Value>(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                bar.draft.components.first { $0.id == component.id }?[keyPath: key]
                    ?? component[keyPath: key]
            },
            set: { new in bar.update(component.id) { $0[keyPath: key] = new } })
    }

    /// The bar's own geometry, split into the three questions people
    /// actually ask of it.
    ///
    /// Eleven sliders in one list gave no clue which mattered; size and
    /// position come first because those are the ones anybody touches.
    @ViewBuilder
    var geometryCard: some View {
        SettingsCard(
            "Bar size and position",
            help: "Adjust the whole bar without changing your widgets.",
            reset: restoreBarGeometry,
            resetEnabled: barSettingsChanged(["height", "position", "sticky"]),
            resetLabel: "Reset to default",
            resetHelp: "Restore 35 pt height, top position and every space"
        ) {
            geometrySlider("Height", key: "height", range: 20...60)
            SettingRow("Position") {
                SegmentedPill(
                    selection: geometryBinding("position", fallback: "top"),
                    options: [.init("top", "Top"), .init("bottom", "Bottom")])
            }
            SettingRow("Show on every space") {
                Toggle("All Spaces", isOn: allSpacesBinding).labelsHidden().toggleStyle(.switch)
            }
        }

        SettingsCard(
            "Spacing",
            help: "Use widget values to keep each component's own spacing.",
            reset: restoreBarSpacing,
            resetEnabled: barSettingsChanged(["padding_left", "padding_right"])
                || bar.draft.componentPadding != nil || bar.draft.componentSpacing != nil,
            resetLabel: "Reset to default",
            resetHelp: "Restore widget spacing and 10 pt bar edges"
        ) {
            SettingRow(
                "Gap between components",
                detail: bar.draft.componentSpacing == nil
                    ? "Using each widget's spacing" : "Bar-wide override"
            ) {
                if bar.draft.componentSpacing == nil {
                    Text("Widget spacing").foregroundStyle(.secondary)
                    Button("Customise") { bar.edit { $0.componentSpacing = 4 } }
                } else {
                    ValueSlider(
                        value: Binding(
                            get: { bar.draft.spacing },
                            set: { value in bar.edit { $0.componentSpacing = value } }),
                        range: 0...40, unit: "pt"
                    ) { _ in }
                }

            }
            SettingRow("Native spacing", help: "Restore each widget's own padding and gap") {
                Button("Use widget values") {
                    bar.edit {
                        $0.componentPadding = nil; $0.componentSpacing = nil
                    }
                }.disabled(bar.draft.componentPadding == nil && bar.draft.componentSpacing == nil)
            }
            SettingRow("Spacing preset") {
                Button("Compact") { bar.edit { $0.componentSpacing = 4 } }
            }
            DisclosureGroup("Advanced: inner spacing") {
                SettingRow("Leading space for all components") {
                    ValueSlider(
                        value: Binding(
                            get: { bar.draft.padding },
                            set: { value in bar.edit { $0.componentPadding = value } }),
                        range: 0...24, unit: "pt"
                    ) { _ in }
                }
            }
            geometrySlider("Left bar margin", key: "padding_left", range: 0...60)
            geometrySlider("Right bar margin", key: "padding_right", range: 0...60)
        }

        SettingsCard(
            "Finishing", help: "Rounding, vertical offset and blur apply to the whole bar.",
            reset: restoreBarFinishing,
            resetEnabled: barSettingsChanged(["corner_radius", "y_offset", "blur_radius"]),
            resetLabel: "Reset to default",
            resetHelp: "Remove bar rounding, vertical offset and blur"
        ) {
            geometrySlider("Corner radius", key: "corner_radius", range: 0...20)
            geometrySlider("Vertical offset", key: "y_offset", range: -20...20)
            geometrySlider("Blur", key: "blur_radius", range: 0...40)
        }
    }

    private func restoreBarGeometry() { resetBarSettings(["height", "position", "sticky"]) }
    private func restoreBarSpacing() {
        resetBarSettings(["padding_left", "padding_right"], resetSpacing: true)
    }
    private func restoreBarFinishing() {
        resetBarSettings(["corner_radius", "y_offset", "blur_radius"])
    }

    private func barSettingsChanged(_ keys: [String]) -> Bool {
        StartupConfiguration.sketchybarKeys.filter { keys.contains($0.key) }.contains {
            bar.draft.geometry[$0.key] != $0.fallback
        }
    }

    private func resetBarSettings(_ keys: [String], resetSpacing: Bool = false) {
        bar.edit { configuration in
            for setting in StartupConfiguration.sketchybarKeys where keys.contains(setting.key) {
                configuration.geometry[setting.key] = setting.fallback
            }
            if resetSpacing {
                configuration.componentPadding = nil
                configuration.componentSpacing = nil
            }
        }
    }

    private var allSpacesBinding: Binding<Bool> {
        Binding(
            get: { bar.draft.geometry["sticky"] == "on" },
            set: { value in bar.edit { $0.geometry["sticky"] = value ? "on" : "off" } })
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
