import CoreGraphics
import Foundation
import Macarchy

/// A full `--query` snapshot of one SketchyBar item.
///
/// This is the document the editor will eventually write, not a view model.
/// The renderer must not invent layout — `frame` is the live bounding rect.
struct SketchybarItem: Identifiable, Hashable, Sendable {
    let members: [String]
    let id: String
    let type: String
    let position: String
    let drawing: Bool
    var frame: CGRect
    let paddingLeft: Double
    let paddingRight: Double
    var width: Double
    var alignment: String?
    var icon: Layer
    var label: Layer
    var background: Background

    struct Layer: Hashable, Sendable {
        var value: String
        var drawing: Bool
        var color: String?
        var font: String?
        var yOffset: Double
        var paddingLeft: Double
        var paddingRight: Double
        var width: Double?
        var alignment: String = "left"
    }

    struct Background: Hashable, Sendable {
        var drawing: Bool
        var color: String?
        var cornerRadius: Double
        var height: Double
        var imageURL: URL?
        var imagePaddingLeft: Double = 0
        var imageYOffset: Double = 0
        var imageScale: Double
    }

    var isOnScreen: Bool { drawing && frame.origin.x > -1000 }

    /// Brackets are groups, not leaves. The updater is a hidden worker.
    var isLeaf: Bool { type != "bracket" && !id.hasSuffix("_updater") }

    static func parse(id: String, json: String) -> SketchybarItem? {
        guard let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let geometry = object["geometry"] as? [String: Any] ?? [:]
        return SketchybarItem(
            members: object["bracket"] as? [String] ?? [],
            id: id,
            type: (object["type"] as? String) ?? "item",
            position: (geometry["position"] as? String) ?? "left",
            drawing: (geometry["drawing"] as? String) == "on",
            frame: Self.rect(object["bounding_rects"]),
            paddingLeft: Self.number(geometry["padding_left"]),
            paddingRight: Self.number(geometry["padding_right"]),
            width: Self.number(geometry["width"]),
            icon: Self.layer(object["icon"] as? [String: Any] ?? [:]),
            label: Self.layer(object["label"] as? [String: Any] ?? [:]),
            background: Self.background(geometry["background"] as? [String: Any] ?? [:])
        )
    }

    private static func layer(_ raw: [String: Any]) -> Layer {
        Layer(
            value: (raw["value"] as? String) ?? "",
            drawing: (raw["drawing"] as? String) == "on",
            color: raw["color"] as? String,
            font: raw["font"] as? String,
            yOffset: number(raw["y_offset"]),
            paddingLeft: number(raw["padding_left"]),
            paddingRight: number(raw["padding_right"]),
            width: number(raw["width"]) > 0 ? number(raw["width"]) : nil,
            alignment: raw["align"] as? String ?? "left"
        )
    }

    private static func background(_ raw: [String: Any]) -> Background {
        let image = raw["image"] as? [String: Any] ?? [:]
        let path = image["value"] as? String
        let imageOn = (image["drawing"] as? String) == "on"
        return Background(
            drawing: (raw["drawing"] as? String) == "on",
            color: raw["color"] as? String,
            cornerRadius: number(raw["corner_radius"]),
            height: number(raw["height"]),
            imageURL: imageOn && path != nil && path != "(null)"
                ? URL(fileURLWithPath: path ?? "") : nil,
            imagePaddingLeft: number(image["padding_left"]),
            imageYOffset: number(image["y_offset"]),
            imageScale: number(image["scale"])
        )
    }

    /// `bounding_rects["display-1"].origin/size` — off-screen items sit at -9999.
    private static func rect(_ raw: Any?) -> CGRect {
        guard let displays = raw as? [String: Any],
            let key = displays.keys.min(),
            let first = displays[key] as? [String: Any]
        else { return .zero }
        let origin = pair(first["origin"])
        let size = pair(first["size"])
        return CGRect(x: origin.x, y: origin.y, width: size.x, height: size.y)
    }

    private static func pair(_ raw: Any?) -> CGPoint {
        if let values = raw as? [Double], values.count == 2 {
            return CGPoint(x: values[0], y: values[1])
        }
        if let values = raw as? [NSNumber], values.count == 2 {
            return CGPoint(x: values[0].doubleValue, y: values[1].doubleValue)
        }
        return .zero
    }

    static func number(_ raw: Any?) -> Double {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) ?? 0 }
        return 0
    }
}

// Only native presentation properties are exposed. Reading values, scripts and
// subscriptions never enter this map, so an edit cannot freeze a live source.
extension SketchybarItem {
    var editableSettings: [String: String] {
        var result: [String: String] = [
            "padding_left": String(paddingLeft), "padding_right": String(paddingRight),
            "width": width > 0 ? String(width) : "dynamic",
            "align": alignment ?? position,
            "background.drawing": background.drawing ? "on" : "off",
            "background.corner_radius": String(background.cornerRadius),
            "background.image.scale": String(background.imageScale),
            "background.image.padding_left": String(background.imagePaddingLeft),
            "background.image.y_offset": String(background.imageYOffset),
            "background.image": background.imageURL?.path ?? "",
            "icon": icon.value,
            "background.image.drawing": background.imageURL == nil ? "off" : "on"
        ]
        for (name, layer) in [("icon", icon), ("label", label)] {
            result[name + ".width"] = layer.width.map { String($0) } ?? "dynamic"
            result[name + ".align"] = layer.alignment
            result[name + ".drawing"] = layer.drawing ? "on" : "off"
            result[name + ".font"] = layer.font
            result[name + ".color"] = layer.color
            result[name + ".y_offset"] = String(layer.yOffset)
            result[name + ".padding_left"] = String(layer.paddingLeft)
            result[name + ".padding_right"] = String(layer.paddingRight)
        }
        result["background.color"] = background.color
        return result
    }

    func presenting(_ component: Macarchy.BarComponent) -> SketchybarItem {
        var copy = self
        let settings = component.presentation[id] ?? [:]
        for (prefix, original) in [("icon", icon), ("label", label)] {
            var layer = original
            if let value = settings[prefix + ".width"] { layer.width = Double(value) }
            if let value = settings[prefix + ".align"] { layer.alignment = value }
            if let value = settings[prefix + ".drawing"] { layer.drawing = value == "on" }
            if let value = settings[prefix + ".font"] { layer.font = value }
            if let value = settings[prefix + ".color"] { layer.color = value }
            if let value = settings[prefix + ".y_offset"], let number = Double(value) {
                layer.yOffset = number
            }
            if let value = settings[prefix + ".padding_left"], let number = Double(value) {
                layer.paddingLeft = number
            }
            if let value = settings[prefix + ".padding_right"], let number = Double(value) {
                layer.paddingRight = number
            }
            if prefix == "icon" { copy.icon = layer } else { copy.label = layer }
        }
        copy.alignment = settings["align"] ?? alignment
        copy.applyImageAndSize(settings)
        return copy
    }

    private mutating func applyImageAndSize(_ settings: [String: String]) {
        if let value = settings["background.image.padding_left"], let number = Double(value) {
            background.imagePaddingLeft = number
        }
        if let value = settings["background.image.y_offset"], let number = Double(value) {
            background.imageYOffset = number
        }
        if let value = settings["icon"] { icon.value = value }
        if let value = settings["background.image.drawing"], value == "off" {
            background.imageURL = nil
        }
        if let value = settings["background.image"], !value.isEmpty {
            background.imageURL = URL(fileURLWithPath: value)
        }
        if let value = settings["background.image.scale"], let number = Double(value) {
            background.imageScale = number
        }
        if let value = settings["width"], let number = Double(value) {
            width = number
            frame.size.width = number
        }
    }
}

// Numeric rows already have a reserved, right-aligned slot. Sensor formatting
// spaces must not add a second alignment offset to the displayed reading.
extension SketchybarItem.Layer {
    var displayValue: String {
        alignment == "right" && value.contains(where: \.isNumber)
            ? value.trimmingCharacters(in: .whitespaces) : value
    }
}
