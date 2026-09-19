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
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache: [String: NSImage] = [:]

    func thumbnail(for url: URL, height: CGFloat) async -> NSImage? {
        let key = "\(url.path)@\(Int(height))"
        if let hit = cache[key] { return hit }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(height * 3)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let image = NSImage(cgImage: cgImage, size: .zero)
        cache[key] = image
        return image
    }
}
