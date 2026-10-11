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

    /// The person's own items run after Macarchy's bar is built, so they can
    /// add to it. Keeping an entire existing bar instead is a setup choice:
    /// it switches the bundled items off rather than layering two bars.
    @discardableResult
    public func generateSketchybarRC(adopting: String? = nil) -> GeneratedFile.Outcome {
        let file = Self.sketchybarrc
        let content =
            Self.header("The bar comes from the Menu Bar page and the active theme.")
            + "\(Paths.cliInShell) startup sketchybar\n\n"
            + region(yours(file, adopting: adopting)) + "\n\n"
            + "sketchybar --update\n"
        return file.write(content, reason: "menu bar startup changed")
    }
}
