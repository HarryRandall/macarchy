import AppKit
import SwiftUI

/// The right-hand pane: the wallpaper, then the theme's details.
struct SwitcherPreview: View {
    let theme: InstalledTheme?
    let showsDetails: Bool
    @State private var image: NSImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                artwork
                if showsDetails, let theme { details(theme) }
            }
            .padding(16)
        }
        .task(id: theme?.wallpaperURL) {
            image = nil
            guard let url = theme?.wallpaperURL else { return }
            image = await Thumbnails.shared.image(for: url, maxPixels: 1400)
        }
    }

    private var artwork: some View {
        Rectangle()
            .fill(theme?.palette?.background ?? .black)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else if theme?.wallpaperURL == nil {
                    Text("No wallpaper in this theme")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func details(_ theme: InstalledTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(theme.title).font(.system(size: 17, weight: .semibold)).padding(.bottom, 10)
            metadata("Mode", theme.isDark ? "Dark" : "Light")
            metadata("Wallpapers", "\(SwitcherBackground.all(in: theme).count)")
            if let background = theme.wallpaperURL {
                metadata("Background", SwitcherBackground(url: background, relativePath: "").name)
            }
            Divider().opacity(0.5).padding(.vertical, 6)
            HStack {
                Text("Accent").foregroundStyle(.secondary)
                Spacer()
                Circle().fill(theme.ringColour).frame(width: 10, height: 10)
            }
            .font(.system(size: 12)).padding(.vertical, 4)
            if let palette = theme.palette {
                HStack(spacing: 6) {
                    Text("ls -la").foregroundStyle(.secondary)
                    Spacer()
                    tag("dir/", palette.blue)
                    tag("link@", palette.cyan)
                    tag("exec*", palette.green)
                    tag("archive", palette.red)
                    tag("file", palette.foreground)
                }
                .font(.system(size: 11, design: .monospaced)).padding(.vertical, 4)
            }
        }
    }

    private func metadata(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.system(size: 12)).padding(.vertical, 4)
    }

    private func tag(_ text: String, _ colour: Color) -> some View {
        Text(text).foregroundStyle(colour)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(colour.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }
}
