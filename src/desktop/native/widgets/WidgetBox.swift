import AppKit
import Macarchy

/// A widget's box on the bar as SketchyBar reports it: a two-line widget's
/// bracket, or the widget's one item.
struct WidgetBox {
    struct Background: Equatable {
        var drawing: String
        var colour: String
        var borderWidth: Int = 0
        var borderColour: String = "0x00000000"

        var highlighted: Background {
            Background(
                drawing: "on", colour: WidgetMenuController.highlightColour,
                borderWidth: drawing == "on" ? borderWidth : 0, borderColour: borderColour)
        }
    }

    /// The bracket or item that draws the box.
    let name: String
    /// Where it is drawn, in screen coordinates, or nil while it is hidden.
    let frame: NSRect?
    /// How its background is drawn now, to put back after a highlight.
    let background: Background

    static func find(_ id: String) async -> WidgetBox? {
        var name = WidgetLook.boxID(id)
        var result = await Integrations().sketchybar(["--query", name])
        if !result.ok {
            name = id
            result = await Integrations().sketchybar(["--query", id])
        }
        guard result.ok, let data = result.stdout.data(using: .utf8),
            let item = try? JSONDecoder().decode(QueriedItem.self, from: data)
        else { return nil }
        let background = item.geometry?.background
        return WidgetBox(
            name: name, frame: frame(item.boundingRects),
            background: Background(
                drawing: background?.drawing ?? "off", colour: background?.color ?? "0x0",
                borderWidth: background?.borderWidth ?? 0,
                borderColour: background?.borderColour ?? "0x00000000"))
    }

    static func paint(_ name: String, _ background: Background) async {
        _ = await Integrations().sketchybar([
            "--set", name, "background.drawing=\(background.drawing)",
            "background.color=\(background.colour)",
            "background.border_width=\(background.borderWidth)",
            "background.border_color=\(background.borderColour)"
        ])
    }

    private static func frame(_ rects: [String: QueriedItem.Rect]) -> NSRect? {
        guard let (display, rect) = rects.min(by: { $0.key < $1.key }) else { return nil }
        let number = Int(display.split(separator: "-").last ?? "") ?? 1
        let screens = NSScreen.screens
        let screen = screens.indices.contains(number - 1) ? screens[number - 1] : NSScreen.main
        // A hidden item is parked far off the display, which is no place to open.
        guard let screen, rect.origin.count == 2, rect.size.count == 2, rect.origin[0] >= 0
        else { return nil }
        // SketchyBar measures from the top-left of its display.
        return NSRect(
            x: screen.frame.minX + rect.origin[0],
            y: screen.frame.maxY - rect.origin[1] - rect.size[1],
            width: rect.size[0], height: rect.size[1])
    }
}

private struct QueriedBackground: Decodable {
    let drawing: String?
    let color: String?
    let borderWidth: Int?
    let borderColour: String?

    enum CodingKeys: String, CodingKey {
        case drawing, color
        case borderWidth = "border_width"
        case borderColour = "border_color"
    }
}

private struct QueriedItem: Decodable {
    struct Rect: Decodable {
        let origin: [Double]
        let size: [Double]
    }
    struct Geometry: Decodable {
        let background: QueriedBackground?
    }
    let boundingRects: [String: Rect]
    let geometry: Geometry?

    enum CodingKeys: String, CodingKey {
        case boundingRects = "bounding_rects"
        case geometry
    }
}
