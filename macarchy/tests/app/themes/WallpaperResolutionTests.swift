import Foundation
import Macarchy
import Testing
@testable import App

struct WallpaperResolutionTests {
    @Test func resolvesRelativeAndAbsoluteWallpaperPaths() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = root.appending(path: "wallpaper.png")
        try Data().write(to: image)
        let relative = InstalledTheme(
            name: "test", directory: root, manifest: Theme(name: "test", wallpaper: "wallpaper.png")
        )
        let absolute = InstalledTheme(
            name: "test", directory: root, manifest: Theme(name: "test", wallpaper: image.path))
        #expect(relative.wallpaperURL == image)
        #expect(absolute.wallpaperURL == image)
    }

    @Test func missingWallpaperFallsBackToAnAvailableBackground() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let backgrounds = root.appending(path: "backgrounds")
        try FileManager.default.createDirectory(at: backgrounds, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let image = backgrounds.appending(path: "available.jpg")
        try Data().write(to: image)
        let theme = InstalledTheme(
            name: "test", directory: root, selectedBackground: "removed.jpg",
            manifest: Theme(name: "test"))
        #expect(theme.wallpaperURL?.resolvingSymlinksInPath() == image.resolvingSymlinksInPath())
    }
}
