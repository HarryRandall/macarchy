import Foundation

public enum DesktopConfiguration {
    /// Restores a snapshot and reapplies everything it can affect, including
    /// skhd, which reads its file only at startup. Returns the files written.
    @discardableResult
    public static func restore(
        _ snapshot: SnapshotStore.Snapshot, store: SnapshotStore = SnapshotStore(),
        integrations: Integrations = Integrations()
    ) async throws -> [URL] {
        // Read before restoring: restoring snapshots the current files, and
        // that capture can prune the snapshot being restored.
        let restartsShortcuts = touchesShortcuts(
            store.originalPaths(of: snapshot), linked: SkhdShortcuts().configURL.path)
        // One lock across restoring and reapplying, so a concurrent change
        // cannot land between them and be applied over a half-restored state.
        return try await OperationLock.run {
            let restored = try store.restore(snapshot)
            try await applyLocked(integrations: integrations)
            if restartsShortcuts, Daemon.skhd.isManaged {
                let result = await integrations.restart(.skhd)
                guard result.ok else { throw ConfigurationError(result.summary) }
            }
            return restored
        }
    }

    /// Whether a snapshot holds the shortcuts file. Shortcut edits snapshot a
    /// linked skhdrc's target, which can have any name.
    static func touchesShortcuts(_ paths: [String], linked: String) -> Bool {
        paths.contains { $0.hasSuffix("/skhdrc") || $0.hasSuffix("/.skhdrc") || $0 == linked }
    }

    /// Reapplies every saved setting under one desktop lock, skipping tools
    /// that are not installed or were left out of setup rather than failing
    /// halfway.
    public static func apply(integrations: Integrations = Integrations()) async throws {
        try await OperationLock.run { try await applyLocked(integrations: integrations) }
    }

    /// The body of `apply`; the caller must hold the desktop lock.
    static func applyLocked(integrations: Integrations) async throws {
        let settings = try SettingsStore().read()
        if let name = settings.currentTheme {
            let result = await ThemeApplication(integrations: integrations).applyLocked(
                name: name)
            guard result.ok else { throw ConfigurationError(result.stderr) }
        }
        if Daemon.yabai.isManaged {
            try await Startup.apply("yabai", integrations: integrations)
        }
        if Daemon.sketchybar.isManaged {
            try await Startup.apply("sketchybar", integrations: integrations)
        }
        try await Startup.applyCorners(integrations: integrations)
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
