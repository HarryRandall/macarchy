import Macarchy
import SwiftUI

/// The bindings behind `ComponentEditor`'s controls.
///
/// Every getter reads the component back out of the draft rather than closing
/// over the copy it was handed, so a control still shows the right value after
/// a neighbouring edit has rebuilt the list.
extension ComponentEditor {
    var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
    }

    /// The component as it stands in the draft right now.
    func live(_ component: BarComponent) -> BarComponent {
        bar.draft.components.first { $0.id == component.id } ?? component
    }

    /// Swaps the glyph picker in, and the editor back when it closes.
    ///
    /// Re-presenting rebuilds the editor, so its tab selection starts over.
    /// That is acceptable for a round trip that only sets one field.
    func presentGlyphPicker(_ component: BarComponent) {
        model.modal.present {
            GlyphPicker(glyph: binding(component, \.icon)) {
                model.modal.present { ComponentEditor(componentID: componentID, close: close) }
            }
        }
    }

    func binding<Value>(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, Value>
    ) -> Binding<Value> {
        Binding(
            get: { live(component)[keyPath: key] },
            set: { new in bar.update(component.id) { $0[keyPath: key] = new } })
    }

    func optionalBinding(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, String?>
    ) -> Binding<String> {
        Binding(
            get: { live(component)[keyPath: key] ?? "" },
            set: { value in
                bar.update(component.id) { $0[keyPath: key] = value.isEmpty ? nil : value }
            })
    }

    func samplesBinding(_ component: BarComponent) -> Binding<String> {
        Binding(
            get: { live(component).sampleValues.joined(separator: ", ") },
            set: { value in
                let parts = value.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                bar.update(component.id) { $0.sampleValues = parts }
            })
    }

    func colourBinding(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, String?>
    ) -> Binding<Color> {
        Binding(
            get: { Color(macarchyHex: live(component)[keyPath: key]) ?? .white },
            set: { colour in
                bar.update(component.id) { $0[keyPath: key] = colour.macarchyString(.argb) }
            })
    }

    func paddingBinding(_ component: BarComponent) -> Binding<Double> {
        Binding(
            get: { bar.draft.padding(for: live(component)) },
            set: { value in bar.update(component.id) { $0.paddingOverride = value } })
    }

    func gapBinding(_ component: BarComponent) -> Binding<Double> {
        Binding(
            get: { bar.draft.spacing(for: live(component)) },
            set: { value in bar.update(component.id) { $0.spacingOverride = value } })
    }
}

extension ComponentEditor {
    func setProperties(_ component: BarComponent, item: SketchybarItem, values: [String: String]) {
        let freezeWidth =
            live(component).boxWidth == nil
                && values.keys.contains(where: {
                    $0.hasSuffix(".font") || $0 == "background.image.scale"
                })
            ? measuredWidth : nil
        let reservation = freezeWidth.flatMap {
            ComponentSizing.reservation(items: nativeItems, component: live(component), width: $0)
        }
        var fitted = values
        let current = item.presenting(live(component))
        if values["icon.font"] != nil || values["label.font"] != nil {
            var candidate = live(component)
            candidate.presentation[item.id, default: [:]].merge(values) { _, new in new }
            let next = item.presenting(candidate)
            let oldWidth = SketchybarFont(current.icon.font).width(current.icon.value)
            let newWidth = SketchybarFont(next.icon.font).width(next.icon.value)
            if current.icon.drawing && current.label.drawing && current.label.paddingLeft < 0 {
                fitted["label.padding_left"] = String(
                    current.label.paddingLeft - (newWidth - oldWidth))
            }

        }
        let member = reservation.flatMap { reserved in nativeItems.first { $0.id == reserved.id } }
        bar.update(component.id) { target in
            if let freezeWidth, let reservation, let member {
                if target.presentationDefaults[member.id]?["width"] == nil {
                    target.presentationDefaults[member.id, default: [:]]["width"] =
                        member.editableSettings["width"]
                }
                target.presentation[member.id, default: [:]]["width"] = String(reservation.width)
                target.boxWidth = freezeWidth
            }

            for (key, value) in fitted {
                if target.presentationDefaults[item.id]?[key] == nil {
                    target.presentationDefaults[item.id, default: [:]][key] =
                        item.editableSettings[key]
                }
                target.presentation[item.id, default: [:]][key] = value
            }
        }
    }

    func nativeNumberBinding(
        _ component: BarComponent, item: SketchybarItem, key: String
    ) -> Binding<Double> {
        Binding(
            get: {
                Double(
                    live(component).presentation[item.id]?[key] ?? item.editableSettings[key] ?? "0"
                ) ?? 0
            }, set: { setProperties(component, item: item, values: [key: String($0)]) })
    }

    func capturedColourBinding(
        _ component: BarComponent, _ key: WritableKeyPath<BarComponent, String?>
    ) -> Binding<Color> {
        Binding(
            get: { Color(macarchyHex: live(component)[keyPath: key]) ?? .white },
            set: { colour in
                bar.update(component.id) { target in
                    for item in bar.items
                    where target.members.contains(item.id) || target.brackets.contains(item.id) {
                        for (property, value) in item.editableSettings
                        where [
                            "icon.color", "label.color", "background.color", "background.drawing",
                            "background.corner_radius"
                        ].contains(property)
                            && target.presentationDefaults[item.id]?[property] == nil
                        {
                            target.presentationDefaults[item.id, default: [:]][property] = value
                        }
                    }
                    target[keyPath: key] = colour.macarchyString(.argb)
                }
            })
    }

    func resetItem(_ id: String, component: BarComponent) {
        bar.update(component.id) { $0.presentation[id] = $0.presentationDefaults[id] }
    }

    func resetPresentation(_ component: BarComponent) {
        bar.update(component.id) {
            $0.presentation = $0.presentationDefaults
            $0.boxWidth = nil
            $0.paddingOverride = nil

            $0.spacingOverride = nil
        }
    }
}
