import Foundation

/// One wallpaper a theme offers, named the way the Raycast switcher named it.
struct SwitcherBackground: Identifiable, Hashable {
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
    static func all(in theme: InstalledTheme) -> [SwitcherBackground] {
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
