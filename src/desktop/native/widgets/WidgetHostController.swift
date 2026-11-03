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
    private var lastTheme: String?
    /// Held while the app runs, so the clock's fallback leaves the clock to
    /// this host (`WidgetHostPresence`).
    private var presence: Int32?
    /// Tries the lock again while another host, or a missing folder before
    /// setup, keeps it from this one.
    private var presenceRetry: Timer?
    /// Keeps App Nap away: napping delays the host's timers and the click
    /// notifications from the bar, which makes widgets and dropdowns lag.
    private var activity: NSObjectProtocol?

    func start() {
        guard observers.isEmpty else { return }
        lastBar = barData()
        lastTheme = currentTheme()
        holdPresence()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping bar widgets and their dropdowns responsive")
        Task { await host.start() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification, event: "system_woke")
        let switched = workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { WidgetHostController.shared.spaceSwitched() }
        }
        observers.append((workspace, switched))
        observe(
            workspace, NSWorkspace.didActivateApplicationNotification, event: "front_app_switched")
        observe(.default, .NSSystemTimeZoneDidChange, event: "timezone_changed")
        observe(
            .default, NSApplication.didChangeScreenParametersNotification, event: "display_changed")
        watchPower()
        watchFiles()
        watchTriggers()
    }

    /// Takes the widget host lock, or keeps trying every half minute, as
    /// often as the clock's fallback runs, until it has it: while it is not
    /// held, the fallback updates the clock as well as this host.
    private func holdPresence() {
        presence = WidgetHostPresence.hold()
        guard presence == nil, presenceRetry == nil else { return }
        presenceRetry = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated {
                let controller = WidgetHostController.shared
                guard let held = WidgetHostPresence.hold() else { return }
                controller.presence = held
                controller.presenceRetry?.invalidate()
                controller.presenceRetry = nil
            }
        }
    }

    /// Events the bar passes on through `macarchy widget trigger`. Windows
    /// can change many times in a moment, so a burst becomes one update.
    private func watchTriggers() {
        let token = DistributedNotificationCenter.default().addObserver(
            forName: WidgetActions.triggerNotification, object: nil, queue: .main
        ) { notification in
            guard AppNotice.isForThisCopy(notification),
                let event = notification.userInfo?["event"] as? String
            else { return }
            MainActor.assumeIsolated { WidgetHostController.shared.coalesce(event) }
        }
        observers.append((DistributedNotificationCenter.default(), token))
        let space = DistributedNotificationCenter.default().addObserver(
            forName: WidgetActions.spaceNotification, object: nil, queue: .main
        ) { notification in
            guard AppNotice.isForThisCopy(notification),
                let index = notification.userInfo?["space"] as? Int
            else { return }
            MainActor.assumeIsolated { WidgetHostController.shared.going(to: index) }
        }
        observers.append((DistributedNotificationCenter.default(), space))
    }

    /// The look again after the latest `macarchy space`; a newer switch
    /// replaces it, so a burst of switches checks once, after the last.
    private var spaceCheck: Task<Void, Never>?
    /// The windows read again once switching stops; a newer switch
    /// replaces it, so a burst of switches reads yabai once.
    private var spaceSettle: Task<Void, Never>?

    /// macOS has switched Space: draw it as current from the window server
    /// at once, then read the windows of each Space once switching settles.
    private func spaceSwitched() {
        spaceSettle?.cancel()
        spaceSettle = Task { [host] in
            await BuiltInReadings.shared.spaceSwitched()
            await host.trigger("space_changed")
            guard (try? await Task.sleep(for: .milliseconds(400))) != nil else { return }
            await host.trigger("space_changed")
        }
    }

    /// A Space is about to be shown: draw it as current now, then look
    /// again once macOS has had time to switch, in case it did not.
    private func going(to space: Int) {
        spaceCheck?.cancel()
        spaceCheck = Task { [host] in
            await BuiltInReadings.shared.expect(space: space)
            await host.trigger("space_changed")
            guard (try? await Task.sleep(for: .seconds(1.6))) != nil else { return }
            await host.trigger("space_changed")
        }
    }

    private var pending: Set<String> = []

    private func coalesce(_ event: String) {
        guard pending.insert(event).inserted else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(60))
            pending.remove(event)
            await host.trigger(event)
        }
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

    /// Watches Macarchy's folder, so a change to the bar or the theme in
    /// `settings.json`, or to any file under `widgets`, restarts the host,
    /// which then draws in the theme's colours. Other writes to settings
    /// leave the widgets running.
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

    /// The files the bar and the theme are read from, at the top of the folder.
    private static let barFiles: Set<String> = [
        "settings.json", "menu-bar.json", "menu-bar-draft.json"
    ]

    private func filesChanged(_ paths: [String]) {
        let root = Paths.appRoot.resolvingSymlinksInPath().path
        let widgets = Paths.widgetsDirectory.resolvingSymlinksInPath().path + "/"
        let urls = paths.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() }
        // Hidden files are a widget's own scratch state, such as a history it
        // keeps between runs; restarting on those would never stop.
        let touchedWidgets = urls.contains {
            !$0.lastPathComponent.hasPrefix(".") && $0.path.hasPrefix(widgets)
        }
        // The daemons' logs, backups and snapshots change often; only a write
        // to the bar's own files is worth reading the settings again for.
        let touchedBar = urls.contains {
            Self.barFiles.contains($0.lastPathComponent)
                && $0.deletingLastPathComponent().path == root
        }
        guard touchedWidgets || touchedBar else { return }
        let bar = barData()
        let theme = currentTheme()
        guard touchedWidgets || bar != lastBar || theme != lastTheme else { return }
        lastBar = bar
        lastTheme = theme
        Task { await host.restart() }
    }

    private func currentTheme() -> String? {
        (try? SettingsStore().read())?.currentTheme
    }

    /// The bar as saved, to tell an edit to it from other settings changes.
    private func barData() -> Data? {
        let configuration = try? BarConfigurationStore().load()
        return configuration.flatMap { try? JSONEncoder().encode($0) }
    }
}
