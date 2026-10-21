import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downsampled wallpapers, encoded for the web view and cached for the life
/// of the app.
///
/// Theme wallpapers are often 6K images; decoding them at full size made the
/// first frame of a preview visibly late. ImageIO decodes straight to the size
/// on screen instead, and the page is handed a JPEG it can draw at once.
actor Thumbnails {
    static let shared = Thumbnails()

    private struct Key: Hashable {
        let path: String
        let modified: Date?
        let maxPixels: Int
    }

    private var cache: [Key: Data] = [:]

    func jpeg(for url: URL, maxPixels: Int) -> Data? {
        let modified =
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        let key = Key(path: url.standardizedFileURL.path, modified: modified, maxPixels: maxPixels)
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
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        let result = data as Data
        cache[key] = result
        return result
    }
}
