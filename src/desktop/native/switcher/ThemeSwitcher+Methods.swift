import Foundation
import Macarchy

extension ThemeSwitcher {
    /// Checks only the running app can make, shown beside the shared ones.
    var healthChecks: [HealthCheck] { Self.healthChecks(shortcutTaken: hotKeyTaken) }

    static func healthChecks(shortcutTaken: Bool) -> [HealthCheck] {
        guard shortcutTaken else { return [] }
        return [
            HealthCheck(
                .optional, "Theme switcher shortcut", .warning,
                "⌘⌃Space is taken, usually by Emoji & Symbols.",
                fix: "Turn that shortcut off in System Settings, Keyboard, Keyboard Shortcuts, "
                    + "then quit and reopen Macarchy.")
        ]
    }

    /// Not private: the contract tests register the same methods to check
    /// them against the shared fixtures.
    func registerMethods(on surface: WebSurface, model: AppModel) {
        let router = surface.router
        router.register("switcher.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return model.switcherState()
        }
        router.register("switcher.refresh") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            await model.themes.reloadInBackground()
            await SwitcherBackground.load(model.themes.themes)
            return model.switcherState()
        }
        router.register("switcher.close") { [weak self] (_: Empty) in
            self?.close()
            return Null()
        }
        router.register("switcher.openSettings") { [weak self] (_: Empty) in
            self?.close()
            SettingsWindow.shared.show()
            return Null()
        }
        router.register("switcher.applyTheme") { [weak self, weak model] (params: ThemeParams) in
            guard let self, let model else {
                throw BridgeFailure(.unavailable, "The app is closing.")
            }
            guard let theme = model.themes.themes.first(where: { $0.name == params.theme }) else {
                throw BridgeFailure(.invalidParams, "There is no theme named \(params.theme).")
            }
            let apply = actions.apply
            try await perform("Could not apply \(theme.title)", model) {
                await apply(model, params.theme)
            }
            return Null()
        }
        router.register("switcher.useBackground") {
            [weak self, weak model] (params: BackgroundParams) in
            guard let self, let model else {
                throw BridgeFailure(.unavailable, "The app is closing.")
            }
            guard let theme = model.themes.themes.first(where: { $0.name == params.theme }),
                let background = SwitcherBackground.all(in: theme).first(where: {
                    $0.relativePath == params.path
                })
            else { throw BridgeFailure(.invalidParams, "That background is not in this theme.") }
            let choose = actions.useBackground
            try await perform("Could not use the \(background.name) background", model) {
                await choose(model, params.theme, params.path)
            }
            return Null()
        }
    }
}
