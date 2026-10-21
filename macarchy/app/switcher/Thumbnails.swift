import AppKit
import ImageIO

/// Downsampled wallpapers, cached for the life of the app.
///
/// Theme wallpapers are often 6K images; decoding them at full size made the
/// first frame of a preview visibly late. ImageIO decodes straight to the
/// size on screen instead.
actor Thumbnails {
    static let shared = Thumbnails()
    private var cache: [String: NSImage] = [:]

    func image(for url: URL, maxPixels: Int) -> NSImage? {
        let key = "\(url.path)#\(maxPixels)"
        if let cached = cache[key] { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        cache[key] = result
        return result
    }
}
