import Foundation
import Macarchy

extension BridgeRouter {
    func registerThemes(
        model: AppModel, actions: ThemeActions = .live, panels: ThemePanels = .live
    ) {
        registerThemeEdits(model: model)
        registerThemeActions(model: model, actions: actions)
        registerThemePanels(model: model, panels: panels)
    }

    private func registerThemeEdits(model: AppModel) {
        register("themes.getState") { (_: Empty) in
            try Self.themeOperation(model) { try model.themesState() }
        }
        register("themes.setDark") { (params: ThemeDarkParams) in
            try Self.themeOperation(model) {
                try ThemeCollection().setDark(theme: params.theme, dark: params.dark)
                return try model.themesState()
            }
        }
        register("themes.setColour") { (params: ThemeColourParams) in
            try Self.themeOperation(model) {
                try ThemeCollection().setColour(
                    theme: params.theme, colour: params.colour, value: params.value)
                return try model.themesState()
            }
        }
        register("themes.setColourscheme") { (params: ThemeColourschemeParams) in
            try Self.themeOperation(model) {
                try ThemeCollection().setColourscheme(theme: params.theme, value: params.value)
                return try model.themesState()
            }
        }
        register("themes.reset") { (params: ThemeParams) in
            try Self.themeOperation(model) {
                try ThemeCollection().reset(theme: params.theme)
                return try model.themesState()
            }
        }
    }

    private func registerThemeActions(model: AppModel, actions: ThemeActions) {
        register("themes.apply") { (params: ThemeParams) in
            try Self.themeOperation(model) {
                _ = try ThemeCollection().directory(named: params.theme)
            }
            let result = await actions.apply(model, params.theme)
            model.log.record(result)
            model.themes.reload()
            guard result.ok else { throw BridgeFailure(.operationFailed, result.summary) }
            return try Self.themeOperation(model) { try model.themesState() }
        }
        register("themes.chooseWallpaper") { (params: BackgroundParams) in
            try Self.themeOperation(model) {
                let directory = try ThemeCollection().directory(named: params.theme)
                let backgrounds = ThemeCollection.backgrounds(in: directory)
                guard
                    backgrounds.contains(where: {
                        String(
                            $0.resolvingSymlinksInPath().path.dropFirst(directory.path.count + 1))
                            == params.path
                    })
                else { throw ConfigurationError("That background is not in this theme.") }
            }
            let result = await actions.useBackground(model, params.theme, params.path)
            model.log.record(result)
            model.themes.reload()
            guard result.ok else { throw BridgeFailure(.operationFailed, result.summary) }
            return try Self.themeOperation(model) { try model.themesState() }
        }
    }

    private func registerThemePanels(model: AppModel, panels: ThemePanels) {
        register("themes.importFolder") { (_: Empty) in
            try Self.themeOperation(model) {
                if let source = panels.importFolder() {
                    let name = try ThemeLibrary().importTheme(from: source)
                    model.log.note("import theme", name)
                }
                return try model.themesState()
            }
        }
        register("themes.exportFolder") { (params: ThemeParams) in
            try Self.themeOperation(model) {
                let source = try ThemeCollection().directory(named: params.theme)
                if let destination = panels.exportFolder(params.theme) {
                    try ThemeLibrary().exportTheme(from: source, to: destination)
                    model.log.note("export theme", params.theme)
                }
                return Null()
            }
        }
        register("themes.reveal") { (params: ThemeParams) in
            try Self.themeOperation(model) {
                panels.reveal(try ThemeCollection().directory(named: params.theme))
                return Null()
            }
        }
    }

    private static func themeOperation<T>(
        _ model: AppModel, _ operation: () throws -> T
    ) throws -> T {
        do {
            let result = try operation()
            model.log.note("themes", "Completed theme operation")
            return result
        } catch {
            model.log.failure("themes", error.localizedDescription)
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}
