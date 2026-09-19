import Foundation
import SwiftUI
import Macarchy

struct InstalledTheme: Identifiable, Sendable {
    let name: String
    let directory: URL
    var values: [String: String] { manifest?.envValues() ?? [:] }

    var id: String { name }

    var accent: Color {
        Color(macarchyHex: manifest?.colors.borderActive ?? values["BORDER_ACTIVE"]) ?? .accentColor
    }
    var isDark: Bool { manifest?.dark ?? (values["DARK_MODE"] != "false") }
    var colorscheme: String? { manifest?.apps.nvimColorscheme ?? values["NVIM_COLORSCHEME"] }

    /// The background actually in force.
    ///
    /// `.backgrounds.json` records the per-theme choice and overrides the
    /// `WALLPAPER` line in theme.env — for most themes the two already disagree,
    /// so reading theme.env alone would show the wrong image.
    var wallpaperRelativePath: String? { selectedBackground ?? manifest?.wallpaper }

    var selectedBackground: String?
    var manifest: Theme?
    var palette: GhosttyPalette?

    var manifestURL: URL { directory.appending(path: Theme.fileName) }

    var wallpaperURL: URL? {
        guard let relative = wallpaperRelativePath, !relative.isEmpty else { return nil }
        let url = directory.appending(path: relative)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Every image the theme ships, for the background picker.
    var availableBackgrounds: [URL] {
        let fm = FileManager.default
        let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]
        return [directory.appending(path: "backgrounds"), directory]
            .flatMap {
                (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? []
            }
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
