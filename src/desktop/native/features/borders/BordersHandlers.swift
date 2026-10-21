import AppKit
import Macarchy
import UniformTypeIdentifiers

extension BridgeRouter {
    func registerBorders(
        model: AppModel,
        pickApplication: @escaping @MainActor () async -> BordersApplication? =
            BordersApplicationPicker.pick
    ) {
        register("borders.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            do { return try await model.bordersState() } catch {
                model.log.failure("read borders", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
        register("borders.apply") { [weak model] (params: BordersApplyParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            do {
                try await model.borderSettings.apply(params.appearance, theme: params.theme)
                model.log.record(CommandResult(command: "borders appearance", status: 0))
                StateBroadcast.shared.settingsWritten()
                model.themes.reload()
                return Null()
            } catch {
                model.log.failure("apply borders", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
        register("borders.pickApplication") { (_: Empty) in await pickApplication() }
    }
}

@MainActor
enum BordersApplicationPicker {
    static func pick() async -> BordersApplication? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        panel.message = "Choose an application that should have no window borders"
        guard await panel.begin() == .OK, let url = panel.url else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        return BordersApplication(name: name, icon: BordersApplication.icon(named: name))
    }
}

extension AppModel {
    var borderSettings: BorderSettings {
        BorderSettings(integrations: backend, store: settingsStore)
    }

    func bordersState() async throws -> BordersState {
        let snapshot = try await borderSettings.read()
        let icons = snapshot.appearance.excludedApps.reduce(into: [String: String]()) {
            icons, name in
            icons[name] = BordersApplication.icon(named: name)
        }
        return BordersState(
            appearance: snapshot.appearance, applicationIcons: icons,
            theme: snapshot.theme, defaults: snapshot.defaults,
            unavailableReason: snapshot.unavailableReason,
            wallpaper: currentThemeWallpaper.map {
                AppScheme.wallpaperURL(file: $0, maxPixels: 1400)
            })
    }
}
