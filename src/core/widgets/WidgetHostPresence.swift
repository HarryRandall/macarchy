import Darwin
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

    /// Takes the lock and returns its descriptor, to keep open for the life
    /// of the host. Nil before setup, so launching never creates Macarchy's
    /// folder, or when another host already holds it.
    public static func hold(at url: URL = defaultURL) -> Int32? {
        let root = url.deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.path),
            (try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)) != nil
        else { return nil }
        let descriptor = open(url.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return descriptor
    }

    /// Whether a host holds the lock now. Never creates the file: with no
    /// lock file, no host has run.
    public static func isHeld(at url: URL = defaultURL) -> Bool {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_SH | LOCK_NB) == 0 else { return errno == EWOULDBLOCK }
        flock(descriptor, LOCK_UN)
        return false
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
