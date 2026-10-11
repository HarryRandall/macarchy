import Foundation

public enum Startup {
    public static func apply(
        _ name: String, integrations: Integrations = Integrations()
    ) async throws {
        let settings = try SettingsStore().read()
        let values = settings.legacyValues
        func require(_ result: CommandResult) throws {
            guard result.ok else {
                throw ConfigurationError(result.command + ": " + result.summary)
            }
        }
        switch name {
        case "yabai":
            for setting in StartupConfiguration.yabaiKeys {
                try require(
                    await integrations.yabaiWrite(
                        setting.key, value: values[setting.env] ?? setting.fallback))
            }
            try await WindowRules.apply(
                settings.floatingApps, customRules: settings.windowRules ?? [],
                integrations: integrations)
        case "sketchybar":
            let arguments = StartupConfiguration.sketchybarKeys.map {
                "\($0.key)=\(values[$0.env] ?? $0.fallback)"
            }
            try require(await integrations.sketchybar(["--bar"] + arguments))
            for (name, visible) in settings.itemVisibility.sorted(by: { $0.key < $1.key }) {
                try require(
                    await integrations.sketchybar([
                        "--set", name, "drawing=\(visible ? "on" : "off")"
                    ]))
            }
            for (name, label) in settings.itemLabels.sorted(by: { $0.key < $1.key }) {
                try require(await integrations.sketchybar(["--set", name, "label=\(label)"]))
            }
            for pair in zip(settings.itemOrder, settings.itemOrder.dropFirst()) {
                try require(await integrations.sketchybar(["--move", pair.1, "after", pair.0]))
            }
            if let configuration = try BarConfigurationStore().load() {
                try await BarCommands.replay(configuration, integrations: integrations)
            }
        case "borders":
            let theme = settings.currentTheme.flatMap {
                Theme.load(from: Paths.themesDirectory.appending(path: $0))
            }
            try require(
                await integrations.borders(BorderCommand.arguments(values: values, theme: theme)))
        default: throw ConfigurationError("Unknown integration: \(name)")
        }
    }
}
