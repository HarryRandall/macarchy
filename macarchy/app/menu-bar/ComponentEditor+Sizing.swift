import AppKit
import Macarchy
import SwiftUI

extension ComponentEditor {
    var measuredWidth: Double {
        guard let component else { return 24 }
        if let width = MenuBarLayout(bar: bar).frames[component.id]?.width { return Double(width) }
        return component.boxWidth ?? Double(MenuBarLayout.customWidth(component))
    }

    var canvasOffsets: [String: Double] {
        guard let component else { return [:] }
        let layout = MenuBarLayout(bar: bar)
        let origin =
            layout.frames[component.id]?.minX ?? nativeItems.filter(\.isOnScreen).map(\.frame.minX)
            .min() ?? 0
        return Dictionary(
            uniqueKeysWithValues: nativeItems.filter(\.isOnScreen).map {
                ($0.id, Double((layout.memberFrames[$0.id]?.minX ?? $0.frame.minX) - origin))
            })
    }

    func makeItFit(_ component: BarComponent) {
        let items = nativeItems.filter(\.isOnScreen)
        let offsets = canvasOffsets
        let padding = bar.draft.padding(for: component)
        let fitted = ComponentSizing.fitting(
            items: items, component: component, offsets: offsets,
            padding: padding, height: bar.height)
        bar.update(component.id) { $0 = fitted }
    }

    func capture(_ values: [String: String], item: SketchybarItem, target: inout BarComponent) {
        for (key, value) in values {
            if target.presentationDefaults[item.id]?[key] == nil {
                target.presentationDefaults[item.id, default: [:]][key] = item.editableSettings[key]
            }
            target.presentation[item.id, default: [:]][key] = value
        }
    }

    func resizeBox(_ component: BarComponent, width: Double, leading: Bool = false) {
        let resized = ComponentSizing.resizing(
            items: nativeItems, component: live(component),
            currentWidth: measuredWidth, width: width, leading: leading)
        bar.update(component.id) { $0 = resized }
    }

    func restoreBox(_ component: BarComponent) {
        bar.update(component.id) { target in
            target.boxWidth = nil
            for id in target.members {
                target.presentation[id]?["width"] = target.presentationDefaults[id]?["width"]
            }
        }
    }

}

/// Measures content without counting the empty reserve in a fixed native slot.
struct ComponentSizing {
    static func resizing(
        items: [SketchybarItem], component: BarComponent,
        currentWidth: Double, width: Double, leading: Bool
    ) -> BarComponent {
        let width = min(max(width.rounded(), component.kind == "spacer" ? 1 : 24), 1000)
        if component.kind == "spacer" {
            var result = component
            result.boxWidth = width
            result.customWidth = width
            return result
        }
        let visible = items.filter(\.isOnScreen)
        let parts = ComponentGeometry(items: visible, component: component).parts
        // Moving the left boundary changes local coordinates, not the content's position.
        var result = ComponentMovement.moving(
            items: visible, component: component, ids: Set(parts.map(\.id)),
            delta: CGSize(width: leading ? width - currentWidth : 0, height: 0))
        if let reservation = reservation(items: visible, component: result, width: width),
            let item = visible.first(where: { $0.id == reservation.id })
        {
            if result.presentationDefaults[item.id]?["width"] == nil {
                result.presentationDefaults[item.id, default: [:]]["width"] =
                    item.editableSettings["width"]
            }
            result.presentation[item.id, default: [:]]["width"] = String(reservation.width)
        }
        result.boxWidth = width
        return result
    }

    static func reservation(
        items: [SketchybarItem], component: BarComponent, width: Double
    ) -> (id: String, width: Double)? {
        let presented = items.filter(\.isOnScreen).map { $0.presenting(component) }
        guard let last = presented.max(by: { $0.frame.maxX < $1.frame.maxX }),
            let origin = presented.map(\.frame.minX).min()
        else { return nil }
        let start =
            component.hasBoxLayout
            ? presented.filter { $0.id != last.id }.reduce(0.0) { $0 + $1.width }
            : last.frame.minX - origin
        return (last.id, max(width - start, 1))
    }

    static func fitting(
        items: [SketchybarItem], component: BarComponent,
        offsets: [String: Double], padding: Double, height: Double
    ) -> BarComponent {
        var result = component
        let visible = items.filter(\.isOnScreen)
        func capture(_ values: [String: String], item: SketchybarItem) {
            for (key, value) in values {
                if result.presentationDefaults[item.id]?[key] == nil {
                    result.presentationDefaults[item.id, default: [:]][key] =
                        item.editableSettings[key]
                }
                result.presentation[item.id, default: [:]][key] = value
            }
        }
        for observed in visible {
            capture(
                fittedProperties(
                    observed.presenting(component), component: component, height: height),
                item: observed)
        }
        let samples = ["Now"] + ComponentSource.describe(component).samples.map(\.0)
        let bounds = samples.map {
            ComponentGeometry(items: visible, component: result, sample: $0, offsets: offsets)
                .contentBounds
        }.reduce(CGRect.null) { $0.union($1) }
        guard !bounds.isNull else {
            result.boxWidth = max(24, MenuBarLayout.customWidth(component))
            return result
        }
        let shift = max(0, -floor(bounds.minX))
        if shift > 0 {
            for item in visible {
                for key in [
                    "icon.padding_left", "label.padding_left", "background.image.padding_left"
                ] {
                    if let raw = result.presentation[item.id]?[key], let x = Double(raw) {
                        result.presentation[item.id]?[key] = String(x + shift)
                        if key != "background.image.padding_left" {
                            let prefix = key.hasPrefix("icon.") ? "icon" : "label"
                            if result.presentation[item.id]?[prefix + ".align"] == "right",
                                let right = Double(
                                    result.presentation[item.id]?[prefix + ".padding_right"] ?? "")
                            {
                                result.presentation[item.id]?[prefix + ".padding_right"] = String(
                                    right - shift)
                            }
                        }
                    }
                }
            }
        }
        let adjusted = samples.map {
            ComponentGeometry(items: visible, component: result, sample: $0, offsets: offsets)
                .contentBounds
        }.reduce(CGRect.null) { $0.union($1) }
        let width = min(1000, max(24, ceil(adjusted.maxX + 3)))
        if let reservation = reservation(items: visible, component: result, width: width),
            let item = visible.first(where: { $0.id == reservation.id })
        {
            capture(["width": String(reservation.width)], item: item)
        }
        result.boxWidth = width
        return result
    }

    private static func fittedProperties(
        _ item: SketchybarItem, component: BarComponent, height: Double
    ) -> [String: String] {
        var values = ComponentGeometry.positionedText(item)
        for (name, layer) in [("icon", item.icon), ("label", item.label)] where layer.drawing {
            let raw = layer.font ?? "SF Pro:Regular:12"
            let font = SketchybarFont(raw).native
            let textHeight = font.ascender - font.descender
            let available = max(height - 6, 1)
            let ratio = min(1, available / max(textHeight, 1))
            if ratio < 1 {
                values[name + ".font"] =
                    raw.split(separator: ":").prefix(2).joined(separator: ":") + ":"
                    + String(font.pointSize * ratio)
            }
            let limit = max(0, (height - 6 - textHeight * ratio) / 2)
            values[name + ".y_offset"] = String(
                min(max(layer.yOffset, -limit), limit).rounded(.towardZero))
        }
        if item.background.imageURL != nil {
            values["background.image.padding_left"] = String(item.background.imagePaddingLeft)
        }
        if let url = item.background.imageURL, let image = NSImage(contentsOf: url),
            image.size.height * item.background.imageScale > height - 6
        {
            values["background.image.scale"] = String(
                max(height - 6, 1) / max(image.size.height, 1))
        }
        if let url = item.background.imageURL, let image = NSImage(contentsOf: url) {
            let scale = Double(values["background.image.scale"] ?? "") ?? item.background.imageScale
            let limit = max(0, (height - 6 - image.size.height * scale) / 2)
            values["background.image.y_offset"] = String(
                min(max(item.background.imageYOffset, -limit), limit).rounded(.towardZero))
        }
        var fitted = component
        fitted.presentation[item.id, default: [:]].merge(values) { _, new in new }
        values.merge(
            ComponentGeometry.reservedReadings(item.presenting(fitted), component: component)
        ) { _, new in new }
        return values
    }

    static func requiredWidth(items: [SketchybarItem], component: BarComponent) -> Double {
        let natural = items.map { item in
            var copy = item
            copy.width = 0
            return copy
        }
        let samples = ["Now"] + ComponentSource.describe(component).samples.map(\.0)
        let bounds = samples.map {
            ComponentGeometry(items: natural, component: component, sample: $0).contentBounds
        }.reduce(CGRect.null) { $0.union($1) }
        return bounds.isNull
            ? max(24, MenuBarLayout.customWidth(component))
            : max(24, ceil(bounds.maxX - min(bounds.minX, 0) + 3))
    }
}
