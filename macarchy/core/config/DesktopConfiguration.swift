import Foundation

public enum DesktopConfiguration {
    /// Restores a snapshot and reapplies everything it can affect, including
    /// skhd, which reads its file only at startup.
    public static func restore(
        _ snapshot: SnapshotStore.Snapshot, store: SnapshotStore = SnapshotStore(),
        integrations: Integrations = Integrations()
    ) async throws {
        // Read before restoring: restoring snapshots the current files, and
        // that capture can prune the snapshot being restored.
        let restartsShortcuts = store.originalPaths(of: snapshot).contains {
            $0.hasSuffix("/skhdrc") || $0.hasSuffix("/.skhdrc")
        }
        try await store.restoreLocked(snapshot)
        try await apply(integrations: integrations)
        if restartsShortcuts, Paths.isInstalled("skhd") {
            let result = await integrations.restart(.skhd)
            guard result.ok else { throw ConfigurationError(result.summary) }
        }
    }

    /// Reapplies every saved setting under one desktop lock, skipping tools
    /// that are not installed rather than failing halfway.
    public static func apply(integrations: Integrations = Integrations()) async throws {
        try await OperationLock.run {
            let settings = try SettingsStore().read()
            if let name = settings.currentTheme {
                let result = await ThemeApplication(integrations: integrations).applyLocked(
                    name: name)
                guard result.ok else { throw ConfigurationError(result.stderr) }
            }
            if Paths.isInstalled("yabai") {
                try await Startup.apply("yabai", integrations: integrations)
            }
            if Paths.isInstalled("sketchybar") {
                try await Startup.apply("sketchybar", integrations: integrations)
            }
            try await Startup.applyCorners(integrations: integrations)
        }
    }
}

extension Startup {
    public static func applyCorners(integrations: Integrations = Integrations()) async throws {
        guard let radius = try SettingsStore().load()["BORDER_RADIUS"] else { return }
        let result: CommandResult
        if radius == "system" {
            let current = await integrations.globalDefault("NSConvolutionOverride1")
            if !current.ok, current.stderr.contains("does not exist") { return }
            result = await integrations.removeGlobalDefault("NSConvolutionOverride1")
        } else {
            result = await integrations.setGlobalDefault("NSConvolutionOverride1", float: radius)
        }
        guard result.ok else { throw ConfigurationError(result.summary) }
    }
}
