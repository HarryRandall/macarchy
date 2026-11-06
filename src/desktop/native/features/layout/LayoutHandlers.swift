import Foundation
import Macarchy

extension BridgeRouter {
    /// The Layout page: reads through and edits with `YabaiLayout`.
    func registerLayout(model: AppModel) {
        register("layout.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            do {
                let snapshot = try await model.yabaiLayout.read()
                model.layout = snapshot
                return model.layoutState(snapshot)
            } catch {
                model.log.failure("read layout", error.localizedDescription)
                throw BridgeFailure(
                    .operationFailed,
                    "Your saved settings could not be read: \(error.localizedDescription)")
            }
        }
        register("layout.apply") { [weak model] (params: LayoutApplyParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let result = await model.yabaiLayout.apply(
                params.changes, linkPadding: params.linkPadding)
            model.log.record(result)
            // The save shows up in the settings folder; it is not news.
            StateBroadcast.shared.settingsWritten()
            guard result.ok else { throw BridgeFailure(.operationFailed, result.stderr) }
            if var snapshot = model.layout {
                snapshot.values = snapshot.values.applying(params.changes)
                model.layout = snapshot
            }
            return Null()
        }
    }
}

extension AppModel {
    func layoutState(_ snapshot: LayoutSnapshot) -> LayoutState {
        LayoutState(
            snapshot,
            wallpaper: currentThemeWallpaper.map {
                AppScheme.wallpaperURL(file: $0, maxPixels: 1400)
            }
        )
    }
}
