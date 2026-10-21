import AppKit
import Macarchy

/// Drawing, hit testing and fitting use the same parts in component coordinates.
struct ComponentGeometry {
    struct Part: Identifiable {
        let member: String
        let layer: String
        let frame: CGRect
        var id: String { member + ":" + layer }
    }

    let items: [SketchybarItem]
    let parts: [Part]
    let offsets: [String: Double]

    init(
        items: [SketchybarItem], component: BarComponent, sample: String = "Now",
        offsets: [String: Double]? = nil
    ) {
        let visible = items.filter { $0.isOnScreen && !$0.id.hasPrefix("gap.") }
        let origin = visible.map(\.frame.minX).min() ?? 0
        self.offsets =
            offsets
            ?? Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0.frame.minX - origin) })
        let values = ComponentSource.describe(component).samples.first { $0.0 == sample }?.1 ?? []
        self.items = visible.map { observed in
            var copy = observed.presenting(component)
            let before = SketchybarTextLayout(copy)
            if !values.isEmpty {
                if copy.icon.drawing, copy.icon.value.contains(where: \.isNumber), values.count > 1
                {
                    copy.icon.value = values[0]
                    if copy.label.drawing { copy.label.value = values[1] }
                } else if copy.label.drawing, copy.label.value.contains(where: \.isNumber) {
                    copy.label.value = values[0]
                }
                // Keep each row's leading edge in place. Native zero-width layers
                // already have independent positions; untouched stacked rows need
                // their coupling removed on the drawing copy only.
                if copy.icon.width == nil && copy.label.width == nil && copy.label.paddingLeft < 0 {
                    copy.icon.width = 0
                    copy.label.width = 0
                    copy.icon.alignment = "left"
                    copy.label.alignment = "left"
                    copy.icon.paddingLeft = before.iconX
                    copy.label.paddingLeft = before.labelX
                    copy.alignment = "left"
                }
            }
            return copy
        }
        var parts: [Part] = []
        for item in self.items {
            let x = self.offsets[item.id] ?? 0
            let layout = SketchybarTextLayout(item)
            for (name, layer, start) in [
                ("icon", item.icon, layout.iconX), ("label", item.label, layout.labelX)
            ]
            where layer.drawing && !layer.value.isEmpty {
                let font = SketchybarFont(layer.font)
                let height = font.native.ascender - font.native.descender
                parts.append(
                    Part(
                        member: item.id, layer: name,
                        frame: CGRect(
                            x: x + start - Self.reservedExtra(layer),
                            y: item.frame.height / 2 - layer.yOffset - height / 2,
                            width: font.width(layer.displayValue) + Self.reservedExtra(layer),
                            height: height)))
            }
            if let part = Self.imagePart(item, x: x) { parts.append(part) }
        }
        self.parts = parts
    }

    private static func reservedExtra(_ layer: SketchybarItem.Layer) -> Double {
        guard layer.alignment == "right", let width = layer.width, width > 0 else { return 0 }
        return max(0, width - SketchybarFont(layer.font).width(layer.displayValue))
    }

    private static func imagePart(_ item: SketchybarItem, x: Double) -> Part? {
        guard let url = item.background.imageURL, let image = NSImage(contentsOf: url) else {
            return nil
        }
        let size = CGSize(
            width: image.size.width * item.background.imageScale,
            height: image.size.height * item.background.imageScale)
        return Part(
            member: item.id, layer: "image",
            frame: CGRect(
                x: x + item.background.imagePaddingLeft,
                y: (item.frame.height - size.height) / 2 - item.background.imageYOffset,
                width: size.width, height: size.height))
    }

    var contentBounds: CGRect { parts.map(\.frame).reduce(CGRect.null) { $0.union($1) } }

    /// Convert coupled native text slots into independent positions, without
    /// touching the values or the scripts which keep supplying them.
    static func positionedText(_ item: SketchybarItem) -> [String: String] {
        let layout = SketchybarTextLayout(item)
        var values = ["align": "left"]
        if item.width <= 0 { values["width"] = String(Double(item.frame.width.rounded())) }
        for (name, layer, x) in [
            ("icon", item.icon, layout.iconX), ("label", item.label, layout.labelX)
        ] where layer.drawing {
            if layer.alignment == "right", let width = layer.width, width > 0 {
                values[name + ".width"] = String(Double(width))
                values[name + ".align"] = "right"
                values[name + ".padding_left"] = String(layer.paddingLeft)
                values[name + ".padding_right"] = String(layer.paddingRight)
                continue
            }
            values[name + ".width"] = "0"
            values[name + ".align"] = "left"
            values[name + ".padding_left"] = String(Double(x.rounded()))
            values[name + ".padding_right"] = "0"
        }
        return values
    }
    /// Reserve the longest known reading while leaving the sensor values untouched.
    static func reservedReadings(
        _ item: SketchybarItem, component: BarComponent
    ) -> [String: String] {
        var values = positionedText(item)
        let samples = ComponentSource.describe(component).samples.map(\.1)
        guard !samples.isEmpty else { return values }
        let layout = SketchybarTextLayout(item)
        let stacked =
            item.icon.drawing && item.icon.value.contains(where: \.isNumber)
            && samples.contains { $0.count > 1 }
        var preceding = 0.0
        for (name, layer, x, index) in [
            ("icon", item.icon, layout.iconX, 0),
            ("label", item.label, layout.labelX, stacked ? 1 : 0)
        ] where layer.drawing {
            let font = SketchybarFont(layer.font)
            if layer.value.contains(where: \.isNumber) {
                let longest =
                    samples.compactMap { $0.indices.contains(index) ? $0[index] : nil }
                    .map { font.width($0) }.max() ?? 0
                let width = max(longest, font.width(layer.displayValue))
                let start =
                    layer.alignment == "right" && (layer.width ?? 0) > 0
                    ? x + font.width(layer.displayValue) - width : x
                values[name + ".width"] = String(Double(width))
                values[name + ".align"] = "right"
                values[name + ".padding_left"] = String((start - preceding).rounded())
                values[name + ".padding_right"] = String((preceding - start).rounded())
                preceding += width
            } else {
                values[name + ".padding_left"] = String((x - preceding).rounded())
            }
        }
        return values
    }

}
