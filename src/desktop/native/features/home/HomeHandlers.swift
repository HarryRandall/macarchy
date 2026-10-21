import Foundation
import Macarchy

extension BridgeRouter {
    func registerHome(model: AppModel) {
        register("home.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            do {
                let state = try await DesktopOverview(
                    integrations: model.backend, store: model.settingsStore
                ).read()
                model.log.note("read home", "Desktop summary refreshed")
                return HomeState(
                    theme: state.theme, themeCount: state.themeCount,
                    shortcutsCount: state.shortcutsCount, layout: state.layout.rawValue,
                    running: state.running, total: state.total,
                    lastChange: state.lastChange?.timeIntervalSince1970,
                    wallpaper: model.currentThemeWallpaper.map {
                        AppScheme.wallpaperURL(file: $0, maxPixels: 1400)
                    }, subtitle: DesignSettings.shared.values.homeTitle)
            } catch {
                model.log.failure("read home", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
    }
}
