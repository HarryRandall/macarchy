import Foundation
import Synchronization

/// One wallpaper a theme offers, named the way the Raycast switcher named it.
struct SwitcherBackground: Identifiable, Hashable, Sendable {
    let url: URL
    /// Path inside the theme folder, which is what settings record.
    let relativePath: String
    var id: String { relativePath }

    /// "backgrounds/2-hand-of-adam.png" reads as "Hand Of Adam".
    var name: String {
        let base = url.deletingPathExtension().lastPathComponent
        let trimmed = base.replacingOccurrences(
            of: "^[0-9]+[-_. ]*", with: "", options: .regularExpression)
        return trimmed.replacingOccurrences(of: "[-_.]+", with: " ", options: .regularExpression)
            .capitalized
    }

    /// Images in `backgrounds/` and the theme root. A root copy identical to
    /// one in `backgrounds/` is the same picture and is listed once.
    ///
    /// Cached per folder state: comparing large wallpapers byte for byte on
    /// every state change would stall the main thread.
    static func all(in theme: InstalledTheme) -> [SwitcherBackground] {
        let key = cacheKey(theme)
        if let cached = cache.withLock({ $0[key] }) { return cached }
        let result = scan(theme)
        cache.withLock { $0[key] = result }
        return result
    }

    /// Works out each theme's backgrounds off the main thread, so building
    /// the switcher's state afterwards only finds them in the cache. The first
    /// scan compares same-sized copies byte for byte, tens of megabytes for
    /// desktop wallpapers, and the switcher builds its state on the main thread.
    static func load(_ themes: [InstalledTheme]) async {
        await Task.detached(priority: .userInitiated) {
            for theme in themes { _ = all(in: theme) }
        }.value
    }

    private static let cache = Mutex<[String: [SwitcherBackground]]>([:])

    /// The folders' paths and modification dates: adding, removing or
    /// renaming an image changes one of them.
    private static func cacheKey(_ theme: InstalledTheme) -> String {
        [theme.directory, theme.directory.appending(path: "backgrounds")].map { url in
            let date =
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(url.path)@\(date)"
        }.joined(separator: "|")
    }

    private static func scan(_ theme: InstalledTheme) -> [SwitcherBackground] {
        let fm = FileManager.default
        var unique: [(url: URL, size: Int)] = []
        for url in theme.availableBackgrounds {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
            let duplicate = unique.contains { existing in
                existing.size == size
                    && existing.url.deletingLastPathComponent() != url.deletingLastPathComponent()
                    && fm.contentsEqual(atPath: existing.url.path, andPath: url.path)
            }
            if !duplicate { unique.append((url, size)) }
        }
        let root = theme.directory.standardizedFileURL.path + "/"
        return unique.map { entry in
            SwitcherBackground(
                url: entry.url,
                relativePath: String(entry.url.standardizedFileURL.path.dropFirst(root.count)))
        }
    }
}
