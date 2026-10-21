import SwiftUI
import AppKit

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache: [String: NSImage] = [:]

    func thumbnail(for url: URL, height: CGFloat) async -> NSImage? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        let key = "\(url.path)@\(Int(height))@\(modified?.timeIntervalSince1970 ?? 0)"
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
