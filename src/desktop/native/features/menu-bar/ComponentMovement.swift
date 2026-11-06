import CoreGraphics
import Macarchy

/// Translate selected parts together while keeping the containing box fixed.
struct ComponentMovement {
    /// A left-edge resize keeps the opposite edge in place.
    static func anchoringRightEdge(
        _ values: [String: String], item: SketchybarItem,
        component: BarComponent, layer: String
    ) -> [String: String] {
        var candidate = component
        candidate.presentation[item.id, default: [:]].merge(values) { _, new in new }
        let before = ComponentGeometry(items: [item], component: component).parts.first {
            $0.layer == layer
        }
        let after = ComponentGeometry(items: [item], component: candidate).parts.first {
            $0.layer == layer
        }
        guard let before, let after else { return values }
        var anchored = values
        let key = layer == "image" ? "background.image.padding_left" : layer + ".padding_left"
        let offset =
            Double(values[key] ?? item.presenting(component).editableSettings[key] ?? "0") ?? 0
        anchored[key] = String((offset + before.frame.maxX - after.frame.maxX).rounded())
        return anchored
    }

    static func moving(
        items: [SketchybarItem], component: BarComponent,
        ids: Set<String>, delta: CGSize
    ) -> BarComponent {
        var result = component
        let parts = ComponentGeometry(items: items, component: component).parts.filter {
            ids.contains($0.id)
        }
        for observed in items where parts.contains(where: { $0.member == observed.id }) {
            let item = observed.presenting(component)
            let selected = parts.filter { $0.member == observed.id }
            var values: [String: String] = [:]
            if selected.contains(where: { $0.layer != "image" }) {
                values = ComponentGeometry.positionedText(item)
            }
            for part in selected {
                if part.layer == "image" {
                    values["background.image.padding_left"] = String(
                        (item.background.imagePaddingLeft + delta.width).rounded())
                    values["background.image.y_offset"] = String(
                        (item.background.imageYOffset - delta.height).rounded())
                    // Image padding also contributes to native dynamic width.
                    values["width"] = String(item.width > 0 ? item.width : item.frame.width)
                } else {
                    let layer = part.layer == "icon" ? item.icon : item.label
                    let layout = SketchybarTextLayout(item)
                    let x = part.layer == "icon" ? layout.iconX : layout.labelX
                    if layer.alignment == "right", (layer.width ?? 0) > 0 {
                        values[part.layer + ".padding_left"] = String(
                            (layer.paddingLeft + delta.width).rounded())
                        values[part.layer + ".padding_right"] = String(
                            (layer.paddingRight - delta.width).rounded())
                    } else {
                        values[part.layer + ".padding_left"] = String((x + delta.width).rounded())
                    }
                    values[part.layer + ".y_offset"] = String(
                        (layer.yOffset - delta.height).rounded())
                }
            }
            for (key, value) in values {
                if result.presentationDefaults[item.id]?[key] == nil {
                    result.presentationDefaults[item.id, default: [:]][key] =
                        item.editableSettings[key]
                }
                result.presentation[item.id, default: [:]][key] = value
            }
        }
        return result
    }
}
