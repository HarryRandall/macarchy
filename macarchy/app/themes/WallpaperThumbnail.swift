import SwiftUI
import AppKit

/// Downsampled wallpaper preview.
///
/// Theme backgrounds are full desktop images — several megabytes each — so they
/// are decoded once at thumbnail size and cached rather than loaded per redraw.
struct WallpaperThumbnail: View {
    let url: URL?
    var height: CGFloat = 92
    /// Which part of the image survives the crop.
    ///
    /// A bar preview is a very wide, very short strip; filling it from the
    /// centre magnifies a thin band out of the middle of the picture, which
    /// reads as a stretch. A bar along the top of the screen should show the
    /// top of the wallpaper.
    var crop: Alignment = .center

    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: crop) {
                if let image {
                    Image(nsImage: image)
                        .resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                    if url == nil {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .frame(width: geometry.size.width, height: height, alignment: crop)
            .clipped()
        }
        .frame(height: height)
        .task(id: "\(url?.absoluteString ?? "")@\(height)") {
            image = nil
            guard let url else { return }
            let loaded = await ThumbnailCache.shared.thumbnail(for: url, height: height * 2)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
