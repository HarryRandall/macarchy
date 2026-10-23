import AppKit
import CoreServices
import IOKit.ps
import Macarchy

/// Runs the widget host for as long as the app runs, and tells it what
/// changed: system events widgets can ask for, and edits to the bar or to
/// any widget's files.
@MainActor
final class WidgetHostController {
    static let shared = WidgetHostController()

    let host = WidgetHost()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var stream: FSEventStreamRef?
    private var lastBar: Data?

    func start() {
        guard observers.isEmpty else { return }
        lastBar = barData()
        Task { await host.start() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification, event: "system_woke")
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification, event: "space_changed")
        observe(
            workspace, NSWorkspace.didActivateApplicationNotification, event: "front_app_switched")
        observe(.default, .NSSystemTimeZoneDidChange, event: "timezone_changed")
        observe(
            .default, NSApplication.didChangeScreenParametersNotification, event: "display_changed")
        watchPower()
        watchFiles()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, event: String) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [host] _ in
            Task { await host.trigger(event) }
        }
        observers.append((center, token))
    }

    /// IOKit calls back on the main run loop when the power source or charge changes.
    private func watchPower() {
        let callback: IOPowerSourceCallbackType = { _ in
            MainActor.assumeIsolated {
                let host = WidgetHostController.shared.host
                Task { await host.trigger("power_source_changed") }
            }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue()
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = source
    }

    /// Watches Macarchy's folder, so a change to the bar in `settings.json`
    /// or to any file under `widgets` restarts the host. Other writes to
    /// settings, such as a theme switch, leave the widgets running.
    private func watchFiles() {
        let root = Paths.appRoot.path
        guard FileManager.default.fileExists(atPath: root) else { return }
        var context = FSEventStreamContext()
        let callback: FSEventStreamCallback = { _, _, count, paths, _, _ in
            let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            MainActor.assumeIsolated {
                WidgetHostController.shared.filesChanged(Array(changed.prefix(count)))
            }
        }
        guard
            let stream = FSEventStreamCreate(
                nil, callback, &context, [root] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3,
                FSEventStreamCreateFlags(
                    kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents))
        else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func filesChanged(_ paths: [String]) {
        let widgets = Paths.widgetsDirectory.resolvingSymlinksInPath().path + "/"
        let touchedWidgets = paths.contains {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path.hasPrefix(widgets)
        }
        let bar = barData()
        guard touchedWidgets || bar != lastBar else { return }
        lastBar = bar
        Task { await host.restart() }
    }

    /// The bar as saved, to tell an edit to it from other settings changes.
    private func barData() -> Data? {
        let configuration = try? BarConfigurationStore().load()
        return configuration.flatMap { try? JSONEncoder().encode($0) }
    }
}
