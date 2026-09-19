import SwiftUI
import AppKit

/// Downsampled wallpaper preview.
///
/// Theme backgrounds are full desktop images — several megabytes each — so they
/// are decoded once at thumbnail size and cached rather than loaded per redraw.
struct WallpaperThumbnail: View {
    let url: URL?
    var height: CGFloat = 92

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                if url == nil {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                }
            }
        }
        .frame(height: height)
        .clipped()
        .task(id: url) {
            guard let url else { return }
            image = await ThumbnailCache.shared.thumbnail(for: url, height: height * 2)
        }
    }
}
