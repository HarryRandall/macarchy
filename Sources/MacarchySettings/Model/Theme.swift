import Foundation
import SwiftUI
import MacarchyKit

struct Theme: Identifiable, Sendable {
    let name: String
    let directory: URL
    let values: [String: String]

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
    var wallpaperRelativePath: String? { selectedBackground ?? values["WALLPAPER"] }

    var selectedBackground: String?
    var manifest: ThemeManifest?
    var palette: GhosttyPalette?

    /// theme.env is no longer read by the app — it is regenerated from the
    /// manifest purely so bordersrc and theme-switch keep working.
    var envURLLegacy: URL { directory.appending(path: "theme.env") }
    var manifestURL: URL { directory.appending(path: ThemeManifest.fileName) }

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
