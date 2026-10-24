import Foundation

/// A read-only summary, independent of any settings page's presentation model.
public struct DesktopOverview: Sendable {
    public struct Snapshot: Sendable {
        public var theme: String?
        public var themeCount: Int
        public var shortcutsCount: Int
        public var layout: LayoutValues.Mode
        public var running: Int
        public var total: Int
        public var lastChange: Date?
    }

    private let integrations: Integrations
    private let store: SettingsStore
    private let themes: URL
    private let shortcuts: URL
    private let snapshots: SnapshotStore

    public init(
        integrations: Integrations = Integrations(), store: SettingsStore = SettingsStore(),
        themes: URL = Paths.themesDirectory,
        shortcuts: URL = Paths.skhdrc,
        snapshots: SnapshotStore = SnapshotStore()
    ) {
        self.integrations = integrations
        self.store = store
        self.themes = themes
        self.shortcuts = shortcuts
        self.snapshots = snapshots
    }

    public func read() async throws -> Snapshot {
        let settings = try store.read()
        let fm = FileManager.default
        let entries =
            fm.fileExists(atPath: themes.path)
            ? try fm.contentsOfDirectory(at: themes, includingPropertiesForKeys: nil) : []
        let installed = entries.filter {
            !$0.lastPathComponent.hasPrefix(".") && Theme.load(from: $0) != nil
        }
        let text =
            fm.fileExists(atPath: shortcuts.path)
            ? try String(contentsOf: shortcuts, encoding: .utf8) : ""
        let layout = try await YabaiLayout(integrations: integrations, store: store).read()
        var running = 0
        for daemon in Daemon.allCases {
            if case .running = await integrations.state(of: daemon) { running += 1 }
        }
        return Snapshot(
            theme: installed.first { $0.lastPathComponent == settings.currentTheme }?
                .lastPathComponent,
            themeCount: installed.count, shortcutsCount: SkhdConfig.parse(text).count,
            layout: layout.values.layout, running: running, total: Daemon.allCases.count,
            lastChange: snapshots.list().map(\.created).max())
    }
}
