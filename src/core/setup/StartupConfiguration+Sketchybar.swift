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

    /// Where the launcher for a person's own bar goes: their bar's folder.
    ///
    /// SketchyBar sets `$CONFIG_DIR`, and its working folder, to the folder
    /// of the file it was started with, links resolved, and passes both to
    /// every item script. A hand-built bar finds its plugins, colours and
    /// icons through them, so starting it from `config/` would break it. The
    /// agent starts this small file instead. It hands over to
    /// `config/sketchybarrc`, so the bar runs Macarchy's file with the folder
    /// it was written for, and SketchyBar still watches that folder for
    /// changes. A link would not do: SketchyBar resolves it.
    public static var barLauncher: URL {
        Paths.home.appending(path: ".config/sketchybar/macarchy-sketchybarrc")
    }

    static let barLauncherMarker = "# Written by Macarchy for its SketchyBar agent."

    static var barLauncherContent: String {
        let home = Paths.home.path
        let config = sketchybarrc.url.path
        let spelled =
            config.hasPrefix(home + "/") ? "$HOME" + config.dropFirst(home.count) : config
        return """
            #!/bin/bash
            \(barLauncherMarker)
            # SketchyBar gives your items this folder as $CONFIG_DIR when it starts
            # here, as it did before Macarchy. The bar itself, with your own region:
            #   \(Paths.display(sketchybarrc.url))
            # Uninstalling Macarchy removes this file.
            exec "\(spelled)" "$@"

            """
    }

    /// Whether the launcher is in place and Macarchy's.
    public static var usesBarLauncher: Bool {
        (try? String(contentsOf: barLauncher, encoding: .utf8))?.contains(barLauncherMarker)
            == true
    }

    /// The file the SketchyBar agent starts.
    public static var sketchybarStartFile: URL {
        usesBarLauncher ? barLauncher : sketchybarrc.url
    }

    public static func envName(forBarKey key: String) -> String? {
        sketchybarKeys.first { $0.key == key }?.env
    }

    /// With Macarchy's bar, the person's own items run after it is built, so
    /// they can add to it. With their own bar, their region builds the items
    /// first and Macarchy then applies geometry and layout edits on top.
    @discardableResult
    public func generateSketchybarRC(adopting: String? = nil) -> GeneratedFile.Outcome {
        let file = Self.sketchybarrc
        // An unreadable settings file must not quietly mean Macarchy's bar,
        // which would reorder a person's own bar around the startup command.
        let bundled: Bool
        do { bundled = try SettingsStore().read().bundledBar ?? true } catch {
            return .failed(error.localizedDescription)
        }
        let startup = "\(Paths.cliInShell) startup sketchybar\n"
        let yours = region(yours(file, adopting: adopting)) + "\n"
        let content =
            Self.header("The bar comes from the Menu Bar page and the active theme.")
            + (bundled ? startup + "\n" + yours : yours + "\n" + startup)
            + "\nsketchybar --update\n"
        return file.write(content, reason: "menu bar startup changed")
    }
}
