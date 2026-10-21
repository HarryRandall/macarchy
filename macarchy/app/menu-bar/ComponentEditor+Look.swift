import AppKit
import Macarchy
import SwiftUI

extension ComponentEditor {
    @ViewBuilder
    func lookTab(_ component: BarComponent) -> some View {
        if !component.isCustom {
            builtInLook(component)
        } else {
            SettingsCard(
                "Static element", help: "Literal text. This element has no live data source."
            ) {
                SettingRow("Name") {
                    TextField("Name", text: binding(component, \.title)).textFieldStyle(
                        .roundedBorder
                    ).frame(width: 190)
                }
                SettingRow("Icon") {
                    TextField("Character", text: binding(component, \.icon)).textFieldStyle(
                        .roundedBorder
                    ).frame(width: 100)
                }
                if component.kind != "spacer" {
                    SettingRow("Text") {
                        TextField("Label", text: binding(component, \.text)).textFieldStyle(
                            .roundedBorder
                        ).frame(width: 190)
                    }
                }
            }
        }
        SettingsCard(
            "Colours", help: "Original restores values captured before your first edit."
        ) {
            colourRow("Readings", component: component, key: \.colour)
            colourRow("Glyph", component: component, key: \.iconColour)
            colourRow("Background", component: component, key: \.backgroundColour)
            SettingRow("Corner radius", help: "For a custom background") {
                ValueSlider(
                    value: binding(component, \.cornerRadius), range: 0...16, unit: "pt",
                    onChange: { _ in })
            }
        }
    }

    @ViewBuilder
    private func builtInLook(_ component: BarComponent) -> some View {
        SettingsCard(
            "Presentation presets", help: "Keeps your existing readings and update scripts."
        ) {
            SettingRow("Layout") {
                HStack {
                    Button("Restore widget defaults") { resetPresentation(component) }

                }
            }
        }
        if let item = iconItem {
            SettingsCard(
                "Icon", help: "Recommended characters use the same font on the desktop."
            ) {
                SettingRow("Show icon") {
                    Toggle(
                        "Show icon",
                        isOn: Binding(
                            get: {
                                let presented = item.presenting(live(component))
                                return presented.icon.drawing
                                    || presented.background.imageURL != nil
                            },
                            set: { show in
                                if show {
                                    restoreIcon(item, component: component)
                                } else {
                                    valuesOnly(component)
                                }
                            })
                    ).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(
                    "Recommended",
                    detail: item.background.imageURL == nil
                        ? "Glyph" : "Current icon is an image"
                ) {
                    HStack(spacing: Metrics.small) {
                        ForEach(
                            Array(Set(ComponentSource.describe(component).icons)).sorted(),
                            id: \.self
                        ) { icon in
                            Button(icon) { chooseIcon(icon, item: item, component: component) }
                                .font(.system(size: 18)).frame(minWidth: 30)
                        }
                        Button("Restore icon") { restoreIcon(item, component: component) }
                    }
                }
                if let url = item.background.imageURL {
                    SettingRow(
                        "Image", detail: url.lastPathComponent, help: "Uses the widget's asset")
                }
            }
        }
    }

    private func colourRow(
        _ title: String, component: BarComponent,
        key: WritableKeyPath<BarComponent, String?>
    ) -> some View {
        let image = title == "Glyph" && iconItem?.presenting(component).background.imageURL != nil
        return SettingRow(
            title,
            help: image ? "Image icons cannot be tinted" : "Override or keep the widget's colour"
        ) {
            ColorWell(
                color: capturedColourBinding(component, key), format: .argb,
                isUnset: component[keyPath: key] == nil
            ) { _ in }
            .disabled(image)
            if component[keyPath: key] != nil {
                Button("Original") { bar.update(component.id) { $0[keyPath: key] = nil } }
            }
        }
    }

    var iconItem: SketchybarItem? {
        nativeItems.first {
            $0.background.imageURL != nil
                || component?.presentationDefaults[$0.id]?["background.image"].map { !$0.isEmpty }
                    == true
        }
            ?? nativeItems.first { $0.icon.drawing && !$0.icon.value.contains(where: \.isNumber) }
    }

    private func chooseIcon(_ value: String, item: SketchybarItem, component: BarComponent) {
        setProperties(
            component, item: item,
            values: [
                "icon": value, "icon.font": "SF Pro:Regular:15", "icon.drawing": "on",
                "background.image.drawing": "off", "icon.y_offset": "0",
                "icon.padding_left": "0", "icon.padding_right": "0"
            ])
    }

    private func restoreIcon(_ item: SketchybarItem, component: BarComponent) {
        let keys = [
            "icon", "icon.font", "icon.drawing", "background.image.drawing", "icon.y_offset",
            "icon.padding_left", "icon.padding_right"
        ]
        bar.update(component.id) { target in
            for key in keys {
                target.presentation[item.id]?[key] = target.presentationDefaults[item.id]?[key]
            }
        }
    }

    private func valuesOnly(_ component: BarComponent) {
        guard let item = iconItem else { return }
        setProperties(
            component, item: item,
            values: ["icon.drawing": "off", "background.image.drawing": "off"])
    }
}
