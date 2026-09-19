import Foundation

public enum Migration {
    public static func run() throws {
        let store = SettingsStore()
        let fm = FileManager.default
        // Never replace existing JSON, including malformed JSON, with legacy settings.
        if !fm.fileExists(atPath: store.url.path) {
            var initial = try store.read()
            initial.currentTheme = try String(
                contentsOf: Paths.themesDirectory.appending(path: ".current"), encoding: .utf8
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let wallpapers = Paths.themesDirectory.appending(path: ".backgrounds.json")
            if fm.fileExists(atPath: wallpapers.path) {
                initial.wallpapers = try JSONDecoder().decode(
                    [String: String].self, from: Data(contentsOf: wallpapers))
            }
            let rules = Paths.home.appending(path: ".config/yabai/float_state.json")
            if fm.fileExists(atPath: rules.path) {
                initial.floatingApps = try JSONDecoder().decode(
                    [String].self, from: Data(contentsOf: rules))
            }
            initial.barConfiguration = try BarConfigurationStore().load()
            try store.update { $0 = initial }
        } else {
            if try store.read().barConfiguration == nil,
                let configuration = try BarConfigurationStore().load()
            {
                try BarConfigurationStore().save(configuration)
            }
        }
        let configuration = StartupConfiguration()
        for outcome in [
            configuration.generateBordersRC(), configuration.generateYabaiRC(),
            configuration.generateSketchybarRC()
        ] {
            if case .failed(let message) = outcome { throw ConfigurationError(message) }
        }
    }
}
