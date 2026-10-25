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
    private var loading: [Key: Task<Data?, Never>] = [:]

    /// Decoding runs outside the actor, so the switcher's background grid
    /// decodes its tiles together rather than one after another; a request
    /// for an image already being decoded waits for that one.
    func jpeg(for url: URL, maxPixels: Int) async -> Data? {
        let modified =
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        let key = Key(path: url.standardizedFileURL.path, modified: modified, maxPixels: maxPixels)
        if let cached = cache[key] { return cached }
        if let pending = loading[key] { return await pending.value }
        let task = Task.detached(priority: .userInitiated) {
            Self.encode(url, maxPixels: maxPixels)
        }
        loading[key] = task
        let data = await task.value
        loading[key] = nil
        if let data { cache[key] = data }
        return data
    }

    private static func encode(_ url: URL, maxPixels: Int) -> Data? {
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
        return data as Data
    }
}
