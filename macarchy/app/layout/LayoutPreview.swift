import SwiftUI

struct LayoutPreview: View {
    let mode: String
    let gap: Double
    let padding: Double
    let wallpaper: URL?

    var body: some View {
        GeometryReader { geometry in
            let inset = max(8, padding * geometry.size.width / 700)
            let spacing = max(3, gap * geometry.size.width / 700)
            ZStack {
                if let wallpaper {
                    WallpaperThumbnail(url: wallpaper, height: geometry.size.height)
                } else {
                    Color.controlWell
                }
                if mode == "bsp" {
                    HStack(spacing: spacing) {
                        window("Main", active: true)
                        VStack(spacing: spacing) {
                            window("Notes"); window("Browser")
                        }
                        .frame(width: max(20, geometry.size.width * 0.35 - inset))
                    }.padding(inset)
                } else {
                    ZStack {
                        window(mode == "stack" ? "" : "Notes").offset(x: 20, y: -10)
                        window(mode == "stack" ? "Current window" : "Main", active: true).offset(
                            x: -12, y: 10)
                    }.frame(
                        width: geometry.size.width * (mode == "stack" ? 0.8 : 0.58),
                        height: geometry.size.height * 0.66)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 9))
        }.accessibilityLabel(
            "Illustrative \(mode == "bsp" ? "tiled" : mode == "stack" ? "stacked" : "freeform") window layout"
        )
    }

    private func window(_ title: String, active: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.cardSurface.opacity(0.95))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in
                        Circle().fill(.secondary.opacity(0.4)).frame(width: 4, height: 4)
                    }
                }.padding(9)
            }
            .overlay {
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6).strokeBorder(
                    active ? Color.accentColor : Color.cardBorder, lineWidth: active ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}
