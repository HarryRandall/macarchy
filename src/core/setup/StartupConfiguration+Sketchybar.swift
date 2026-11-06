import Foundation

extension StartupConfiguration {
    public static let sketchybarKeys: [SettingKey] = [
        SettingKey(key: "height", env: "SKETCHYBAR_HEIGHT", fallback: "35"),
        SettingKey(key: "position", env: "SKETCHYBAR_POSITION", fallback: "top"),
        SettingKey(key: "padding_left", env: "SKETCHYBAR_PADDING_LEFT", fallback: "10"),
        SettingKey(key: "padding_right", env: "SKETCHYBAR_PADDING_RIGHT", fallback: "10"),
        SettingKey(key: "blur_radius", env: "SKETCHYBAR_BLUR_RADIUS", fallback: "0"),
        SettingKey(key: "corner_radius", env: "SKETCHYBAR_CORNER_RADIUS", fallback: "0"),
        SettingKey(key: "y_offset", env: "SKETCHYBAR_Y_OFFSET", fallback: "0"),
        SettingKey(key: "sticky", env: "SKETCHYBAR_STICKY", fallback: "on")
    ]

    public static func envName(forBarKey key: String) -> String? {
        sketchybarKeys.first { $0.key == key }?.env
    }

    /// Startup sets up the bar and its widgets; the person's own commands
    /// run after, so they can add to it.
    @discardableResult
    public func generateSketchybarRC(adopting: String? = nil) -> GeneratedFile.Outcome {
        let file = Self.sketchybarrc
        let content =
            Self.header("The bar and its widgets come from the Menu Bar page and the theme.")
            + "\(Paths.cliInShell) startup sketchybar\n\n"
            + region(yours(file, adopting: adopting)) + "\n"
            + "\nsketchybar --update\n"
        return file.write(content, reason: "menu bar startup changed")
    }
}
