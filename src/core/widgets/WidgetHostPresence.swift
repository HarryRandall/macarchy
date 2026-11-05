import Foundation

/// Whether a widget host is running for this home. The app, or
/// `macarchy widget run`, holds a lock on `state/widget-host.lock` for as
/// long as it runs; the lock goes with the process, however it ends. The
/// clock's fallback, which SketchyBar runs itself, checks it so it only
/// updates the clock while nothing else does.
public enum WidgetHostPresence {
    public static var defaultURL: URL {
        Paths.stateDirectory.appending(path: "widget-host.lock")
    }

    /// Takes the lock, to keep open for the life of the host; see
    /// `PresenceLock.hold`.
    public static func hold(at url: URL = defaultURL) -> Int32? {
        PresenceLock.hold(at: url)
    }

    /// Whether a host holds the lock now.
    public static func isHeld(at url: URL = defaultURL) -> Bool {
        PresenceLock.isHeld(at: url)
    }
}

extension WidgetHost {
    /// Updates one clock once, as SketchyBar asks while no host runs. Only a
    /// widget reading the date is updated, so a widget's own script never
    /// runs more often than it asked to.
    public static func fallback(
        _ id: String, integrations: Integrations = Integrations()
    ) async throws {
        let configuration = try BarConfigurationStore().load()
        let host = WidgetHost(
            integrations: integrations, runner: WidgetProviderRunner(timeout: 2),
            load: { (configuration, WidgetCatalogue().read()) })
        await host.reload()
        guard await host.instances.contains(where: { $0.id == id && $0.manifest.source == "date" })
        else { return }
        if let result = await host.refresh([id]), !result.ok {
            throw ConfigurationError(result.summary)
        }
    }
}
