import Foundation

public struct BorderSnapshot: Sendable {
    public var appearance: BorderAppearance
    public var theme: String?
    public var defaults: BorderAppearance?
    public var unavailableReason: String?
}

/// Reads border preferences and the global corner override without changing the desktop.
public struct BorderSettings: Sendable {
    private let integrations: Integrations
    private let store: SettingsStore
    private let themes: URL
    private let resources: URL?

    public init(
        integrations: Integrations = Integrations(), store: SettingsStore = SettingsStore(),
        themes: URL = Paths.themesDirectory, resources: URL? = Paths.resources
    ) {
        self.integrations = integrations
        self.store = store
        self.themes = themes
        self.resources = resources
    }

    public func read() async throws -> BorderSnapshot {
        let document = try store.read()
        let values = document.flatValues
        var appearance = BorderAppearance()
        appearance.width = values["BORDER_WIDTH"].flatMap(Double.init) ?? 6
        appearance.visible = values["BORDERS_VISIBLE"] != "false"
        appearance.excludedApps = (values["BORDERS_BLACKLIST"] ?? "iPhone Mirroring")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        appearance.radius = values["BORDER_RADIUS"].flatMap(Double.init)
        let radius = await integrations.globalDefault("NSConvolutionOverride1")
        if radius.ok,
            let value = Double(radius.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            appearance.radius = value
        } else if radius.stderr.contains("does not exist") {
            appearance.radius = nil
        } else {
            throw ConfigurationError("Could not read window corners: \(radius.summary)")
        }
        var reason: String?
        let theme = document.currentTheme
        var defaults: BorderAppearance?
        if let theme, let manifest = Theme.load(from: themes.appending(path: theme)) {
            appearance.activeColour = manifest.colors.borderActive
            appearance.inactiveColour = manifest.colors.borderInactive
            if let resources,
                let original = Theme.load(from: resources.appending(path: "themes/\(theme)"))
            {
                var baseline = BorderAppearance()
                baseline.activeColour = original.colors.borderActive
                baseline.inactiveColour = original.colors.borderInactive
                defaults = baseline
            }
        } else {
            reason = "The active theme is unavailable. Your saved border settings are shown."
        }
        if !(await integrations.state(of: .borders)).isRunning {
            reason =
                FileManager.default.isExecutableFile(atPath: Paths.borders)
                ? "borders is not running, so these are your saved settings. Start it to apply edits."
                : "borders isn't installed, so these are your saved settings. Install it to apply edits."
        }
        return BorderSnapshot(
            appearance: appearance, theme: theme, defaults: defaults,
            unavailableReason: reason)
    }

    public func apply(_ appearance: BorderAppearance, theme: String) async throws {
        // Resolve the theme from settings, never from a path supplied by the page.
        guard try store.read().currentTheme == theme else {
            throw ConfigurationError(
                "The active theme changed. Discard this draft and edit the current theme.")
        }
        try await BorderEdit.apply(
            appearance, directory: themes.appending(path: theme),
            integrations: integrations, store: store, expectedTheme: theme)
    }
}
