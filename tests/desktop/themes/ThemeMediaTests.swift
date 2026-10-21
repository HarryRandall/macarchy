import Foundation
import Testing

@testable import App

struct ThemeMediaTests {
    @Test("theme thumbnails refuse traversal, non-images and symbolic links outside the collection")
    func containment() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: "theme-media-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        let themes = root.appending(path: "themes")
        let directory = themes.appending(path: "sample")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let image = directory.appending(path: "one.png")
        try Data().write(to: image)
        try Data().write(to: root.appending(path: "private.png"))
        try fm.createSymbolicLink(
            at: directory.appending(path: "link.png"),
            withDestinationURL: root.appending(path: "private.png"))
        try fm.createSymbolicLink(at: themes.appending(path: "linked"), withDestinationURL: root)
        let allowed = try #require(
            URL(string: AppScheme.themeImageURL(theme: "sample", path: "one.png", maxPixels: 200)))
        #expect(
            AppScheme.themeImage(for: allowed, themesDirectory: themes)?.resolvingSymlinksInPath()
                .path == image.resolvingSymlinksInPath().path)
        for path in [
            "sample/../private.png", "sample/..%2F..%2Fprivate.png", "sample/%2e%2e/private.png",
            "sample/theme.json", "sample/link.png", "linked/private.png"
        ] {
            let url = try #require(URL(string: "macarchy-app://media/theme/\(path)"))
            #expect(AppScheme.themeImage(for: url, themesDirectory: themes) == nil)
        }
    }
}
