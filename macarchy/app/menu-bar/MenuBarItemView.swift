import AppKit
import SwiftUI

/// Paints one parsed SketchyBar item using only the query fields.
///
/// No per-kind layout. Icon / label / background sit where SketchyBar put
/// them — including negative label padding, which is how stacked metrics work.
struct MenuBarItemView: View {
    let item: SketchybarItem
    var dimmed = false
    /// Colours from the draft, drawn instead of the queried ones.
    ///
    /// The query is a snapshot of what SketchyBar is showing now, so on its
    /// own this view can never preview an unapplied edit — restyling a widget
    /// looked like it did nothing until Apply landed.
    var iconOverride: String?
    var labelOverride: String?

    var body: some View {
        let layout = SketchybarTextLayout(item)
        return Color.clear
            .frame(width: item.frame.width, height: item.frame.height)
            .overlay(alignment: .leading) { backdrop }
            .overlay(alignment: .leading) {
                glyph(item.icon, override: iconOverride).offset(x: layout.iconX)
            }
            .overlay(alignment: .leading) {
                glyph(item.label, override: labelOverride).offset(x: layout.labelX)
            }
            .opacity(dimmed ? 0.28 : 1)
    }

    @ViewBuilder
    private var backdrop: some View {
        if let url = item.background.imageURL, let image = NSImage(contentsOf: url) {
            let scale = max(item.background.imageScale, 0.01)
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                .frame(width: item.frame.width, height: item.frame.height, alignment: .leading)
                .offset(x: item.background.imagePaddingLeft, y: -item.background.imageYOffset)
        } else if item.background.drawing {
            RoundedRectangle(cornerRadius: item.background.cornerRadius, style: .continuous)
                .fill(Color(macarchyHex: item.background.color) ?? .clear)
                .frame(
                    height: item.background.height > 0
                        ? item.background.height : item.frame.height)
        }
    }

    @ViewBuilder
    private func glyph(_ layer: SketchybarItem.Layer, override: String?) -> some View {
        if layer.drawing, !layer.value.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(layer.displayValue)
                .font(SketchybarFont(layer.font).swiftUI)
                .foregroundStyle(
                    Color(macarchyHex: override) ?? Color(macarchyHex: layer.color) ?? .white
                )
                // SketchyBar uses an upward-positive text coordinate system.
                .offset(y: -layer.yOffset)
                .lineLimit(1)
                .fixedSize()
        }
    }

}
