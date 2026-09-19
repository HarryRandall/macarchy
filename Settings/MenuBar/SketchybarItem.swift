import CoreGraphics
import Foundation

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
    let frame: CGRect
    let paddingLeft: Double
    let paddingRight: Double
    let width: Double
    let icon: Layer
    let label: Layer
    let background: Background

    struct Layer: Hashable, Sendable {
        var value: String
        var drawing: Bool
        var color: String?
        var font: String?
        var yOffset: Double
        var paddingLeft: Double
        var paddingRight: Double
    }

    struct Background: Hashable, Sendable {
        var drawing: Bool
        var color: String?
        var cornerRadius: Double
        var height: Double
        var imageURL: URL?
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
            paddingRight: number(raw["padding_right"])
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
            imageScale: number(image["scale"])
        )
    }

    /// `bounding_rects["display-1"].origin/size` — off-screen items sit at -9999.
    private static func rect(_ raw: Any?) -> CGRect {
        guard let displays = raw as? [String: Any],
            let first = displays.values.first as? [String: Any]
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
