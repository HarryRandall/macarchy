import Foundation
import Macarchy

struct InstalledTheme: Identifiable, Sendable, Equatable {
    let name: String
    let directory: URL
    var values: [String: String] { manifest?.flatValues() ?? [:] }

    var id: String { name }

    var isDark: Bool { manifest?.dark ?? (values["DARK_MODE"] != "false") }
    var colorscheme: String? { manifest?.apps.nvimColorscheme ?? values["NVIM_COLORSCHEME"] }

    /// The background actually in force: the saved per-theme choice, then the
    /// manifest's default.
    var wallpaperRelativePath: String? { selectedBackground ?? manifest?.wallpaper }

    var selectedBackground: String?
    var manifest: Theme?
    var terminal: TerminalPalette?

    var manifestURL: URL { directory.appending(path: Theme.fileName) }

    var wallpaperURL: URL? {
        guard let relative = wallpaperRelativePath, !relative.isEmpty else {
            return availableBackgrounds.first
        }
        let expanded = (relative as NSString).expandingTildeInPath
        let url =
            expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded) : directory.appending(path: relative)
        return FileManager.default.fileExists(atPath: url.path) ? url : availableBackgrounds.first
    }

    /// Every image the theme ships, for the background picker.
    var availableBackgrounds: [URL] {
        ThemeCollection.backgrounds(in: directory)
    }
}
