import Foundation

public enum Doctor {
    // This is the ordered diagnostic checklist, with no side effects.
    // swiftlint:disable:next function_body_length
    public static func check(integrations: Integrations = Integrations()) async -> CommandResult {
        var messages: [String] = []
        var failures = 0
        func check(_ success: Bool, _ message: String) {
            messages.append("\(success ? "PASS" : "FAIL") \(message)")
            if !success { failures += 1 }
        }
        for daemon in Daemon.allCases {
            let state = await integrations.state(of: daemon)
            check(state.isRunning, "\(daemon.rawValue) running")
        }
        check(await integrations.yabaiRead("window_gap").ok, "yabai responds")
        check(await integrations.barState().0.ok, "SketchyBar responds")
        do {
            let settings = try SettingsStore().read()
            check(
                FileManager.default.fileExists(atPath: SettingsStore().url.path),
                "JSON settings installed")
            if let name = settings.currentTheme {
                let directory = Paths.themesDirectory.appending(path: name)
                let theme = try Theme.read(from: directory)
                check(true, "Active theme is valid")
                if let wallpaper = settings.wallpapers[name] ?? theme.wallpaper {
                    check(
                        FileManager.default.fileExists(
                            atPath: directory.appending(path: wallpaper).path), "Wallpaper exists")
                }
            } else {
                check(false, "Active theme selected")
            }
            for directory in try FileManager.default.contentsOfDirectory(
                at: Paths.themesDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            where !directory.lastPathComponent.hasPrefix(".") {
                guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                else { continue }
                do {
                    _ = try Theme.read(from: directory)
                    check(true, "Theme \(directory.lastPathComponent)")
                } catch {
                    check(
                        false, "Theme \(directory.lastPathComponent): \(error.localizedDescription)"
                    )
                }
            }
        } catch { check(false, "Settings: \(error.localizedDescription)") }
        for file in [
            StartupConfiguration.bordersrc, StartupConfiguration.yabairc,
            StartupConfiguration.sketchybarrc
        ] {
            check(
                await integrations.execute("/bin/bash", ["-n", file.url.path]).ok,
                "\(file.url.lastPathComponent) syntax")
            check(!file.hasDrifted, "\(file.url.lastPathComponent) matches generated version")
        }
        let signals = await integrations.execute(Paths.yabai, ["-m", "signal", "--list"])
        let parsed =
            try? JSONSerialization.jsonObject(with: Data(signals.stdout.utf8)) as? [[String: Any]]
        check(signals.ok && !(parsed ?? []).isEmpty, "yabai signals registered")
        let ghostty = try? String(
            contentsOf: Paths.home.appending(path: ".config/ghostty/config"), encoding: .utf8)
        check(
            ghostty?.components(separatedBy: "THEME COLORS").count == 2,
            "Ghostty has one theme block")
        messages.append("\(failures) failed")
        return CommandResult(
            command: "doctor", status: failures == 0 ? 0 : 1,
            stdout: messages.joined(separator: "\n"),
            stderr: failures == 0 ? "" : "Desktop checks failed")
    }
}
