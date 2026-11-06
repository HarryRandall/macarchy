import AppKit
import CoreText
import SwiftUI

/// The same resolved face is used to measure and draw each native text layer.
struct SketchybarFont {
    let native: NSFont
    let swiftUI: Font

    init(_ raw: String?) {
        let parts = (raw ?? "SF Pro:Regular:12").split(separator: ":").map(String.init)
        let family = parts.first ?? "SF Pro"
        let style = parts.count > 1 ? parts[1] : "Regular"
        let size = parts.count > 2 ? Double(parts[2]) ?? 12 : 12
        let weight: NSFont.Weight
        switch style.lowercased() {
        case "bold": weight = .bold
        case "semibold": weight = .semibold
        case "medium": weight = .medium
        case "heavy": weight = .heavy
        default: weight = .regular
        }
        if family.hasPrefix("SF") {
            native = .systemFont(ofSize: size, weight: weight)
        } else {
            native =
                NSFont(name: family + "-" + style, size: size)
                ?? NSFont(name: family, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
        swiftUI = Font(native)
    }

    func width(_ value: String) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: value, attributes: [.font: native]))
        // SketchyBar reserves rounded glyph-path bounds, rather than advance width.
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return floor(bounds.width + 1.5)
    }
}

struct SketchybarTextLayout {
    let iconX: CGFloat
    let labelX: CGFloat

    init(_ item: SketchybarItem) {
        let iconLength = Self.length(item.icon)
        let labelLength = Self.length(item.label)
        // Native item alignment defaults to its side, including right alignment
        // inside a fixed-width slot. Queried windows can intentionally overlap.
        let extra = max(item.width - iconLength - labelLength, 0)
        let origin =
            (item.alignment ?? item.position) == "right"
            ? extra
            : (item.alignment ?? item.position) == "center" ? extra / 2 : 0
        iconX = origin + Self.glyphOffset(item.icon)
        labelX = origin + iconLength + Self.glyphOffset(item.label)
    }

    private static func glyphOffset(_ layer: SketchybarItem.Layer) -> CGFloat {
        let natural = max(
            0,
            SketchybarFont(layer.font).width(layer.displayValue) + layer.paddingLeft
                + layer.paddingRight)
        let spare = (layer.width ?? natural) - natural
        let adjustment =
            layer.width == nil
            ? 0
            : layer.alignment == "right"
                ? spare
                : layer.alignment == "center" ? spare / 2 : 0
        return layer.paddingLeft + adjustment
    }

    private static func length(_ layer: SketchybarItem.Layer) -> CGFloat {
        guard layer.drawing else { return 0 }
        if let width = layer.width { return width }
        return max(
            0,
            SketchybarFont(layer.font).width(layer.displayValue) + layer.paddingLeft
                + layer.paddingRight)
    }
}

/// Converts native dimensions to a canvas scale without cropping an edited item.
struct ComponentPreviewFit {
    static func dragStep(translation: CGSize, consumed: CGSize, scale: Double) -> CGSize {
        CGSize(
            width: ((translation.width - consumed.width) / max(scale, 0.01)).rounded(),
            height: ((translation.height - consumed.height) / max(scale, 0.01)).rounded())
    }

    static func scale(content: CGSize, available: CGSize) -> CGFloat {
        min(
            2, max(available.width - 24, 1) / max(content.width, 1),
            max(available.height - 12, 1) / max(content.height, 1))
    }
}

extension SketchybarItem {
    var drawingBounds: CGRect {
        let layout = SketchybarTextLayout(self)
        var bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        for (layer, x) in [(icon, layout.iconX), (label, layout.labelX)] where layer.drawing {
            let font = SketchybarFont(layer.font)
            bounds = bounds.union(
                CGRect(
                    x: x, y: frame.height / 2 - layer.yOffset - font.native.pointSize,
                    width: font.width(layer.displayValue), height: font.native.pointSize * 1.3))
        }
        if let url = background.imageURL, let image = NSImage(contentsOf: url) {
            bounds = bounds.union(
                CGRect(
                    x: background.imagePaddingLeft,
                    y: (frame.height - image.size.height * background.imageScale) / 2
                        - background.imageYOffset,
                    width: image.size.width * background.imageScale,
                    height: image.size.height * background.imageScale))
        }
        return bounds
    }
}
