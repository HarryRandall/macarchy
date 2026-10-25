import Foundation
import Macarchy

/// The switcher's two desktop-changing actions.
struct ThemeActions {
    var apply: @MainActor (AppModel, String) async -> CommandResult
    var useBackground: @MainActor (AppModel, String, String) async -> CommandResult

    static var live: ThemeActions {
        ThemeActions(
            apply: { model, name in
                await ThemeApplication(integrations: model.backend).apply(name: name)
            },
            useBackground: { model, name, path in
                await ThemeApplication(integrations: model.backend).chooseWallpaper(
                    theme: name, path: path)
            })
    }
}
