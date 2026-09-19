import AppKit
import SwiftUI

/// Paints one parsed SketchyBar item using only the query fields.
///
/// No per-kind layout. Icon / label / background sit where SketchyBar put
/// them — including negative label padding, which is how stacked metrics work.
struct MenuBarItemView: View {
    let item: SketchybarItem
    var dimmed = false

    var body: some View {
        ZStack(alignment: .leading) {
            backdrop
            HStack(spacing: 0) {
                glyph(item.icon)
                glyph(item.label)
            }
        }
        .frame(width: item.frame.width, height: item.frame.height, alignment: .leading)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if item.background.drawing {
            RoundedRectangle(cornerRadius: item.background.cornerRadius, style: .continuous)
                .fill(Color(macarchyHex: item.background.color) ?? .clear)
                .frame(
                    height: item.background.height > 0
                        ? item.background.height : item.frame.height)
        }
    }

    @ViewBuilder
    private func glyph(_ layer: SketchybarItem.Layer) -> some View {
        if layer.drawing, !layer.value.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(layer.value)
                .font(Self.font(layer.font))
                .foregroundStyle(Color(macarchyHex: layer.color) ?? .white)
                .padding(.leading, layer.paddingLeft)
                .padding(.trailing, layer.paddingRight)
                .offset(y: layer.yOffset)
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// `SF Pro:Semibold:15.00`. SF stays `.system` so calendar/battery
    /// private-use symbols resolve; everything else is the named face
    /// (`sketchybar-app-font` for `:firefox:` ligatures).
    private static func font(_ raw: String?) -> Font {
        let parts = (raw ?? "").split(separator: ":")
        let size = Double(parts.count > 2 ? parts[2] : "") ?? 12
        let family = parts.isEmpty ? "" : String(parts[0])
        let weight = parts.count > 1 ? String(parts[1]) : ""
        if family.hasPrefix("SF") || family.isEmpty {
            return .system(size: size, weight: weight == "Bold" ? .bold : .semibold)
        }
        return .custom(family, size: size)
    }
}
