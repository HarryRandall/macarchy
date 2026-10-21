import Foundation

public enum BorderEdit {
    /// Applies an appearance to the running borders, then saves it.
    ///
    /// The global corner override is changed first, then borders, then
    /// settings.json and finally theme.json. If any step fails, the steps
    /// already taken are put back, so the desktop, the settings and the theme
    /// never disagree about what was applied.
    public static func apply(
        _ appearance: BorderAppearance, directory: URL, integrations: Integrations = Integrations(),
        store: SettingsStore = SettingsStore(), expectedTheme: String? = nil
    ) async throws {
        try await OperationLock.run(root: store.url.deletingLastPathComponent()) {
            try validate(appearance)
            let document = try store.read()
            if let expectedTheme, document.currentTheme != expectedTheme {
                throw ConfigurationError(
                    "The active theme changed. Discard this draft and try again.")
            }
            guard (await integrations.state(of: .borders)).isRunning else {
                throw ConfigurationError("borders is not running. Nothing was saved.")
            }
            let original = try Theme.read(from: directory)
            var theme = original
            theme.colors.borderActive = appearance.activeColour
            theme.colors.borderInactive = appearance.inactiveColour
            try theme.validate()
            let values = settingsValues(appearance)
            let previousRadius = try await corners(integrations)
            if original != theme {
                try SnapshotStore(
                    root: store.url.deletingLastPathComponent().appending(path: "snapshots")
                ).capture(
                    [directory.appending(path: Theme.fileName)], reason: "border colours")
            }
            var changedCorners = false
            var savedSettings = false
            do {
                changedCorners = try await setCorners(
                    appearance.radius, previous: previousRadius, integrations)
                let result = await integrations.borders(
                    BorderCommand.arguments(values: values, theme: theme))
                guard result.ok else { throw ConfigurationError(result.summary) }
                try store.write(values)
                savedSettings = true
                if original != theme { try theme.write(to: directory) }
            } catch {
                var failures: [String] = []
                if savedSettings {
                    do {
                        try store.update { $0.borders = document.borders }
                    } catch let rollback {
                        failures.append(rollback.localizedDescription)
                    }
                }
                if changedCorners,
                    let failure = await restoreCorners(previousRadius, integrations)
                {
                    failures.append(failure)
                }
                guard failures.isEmpty else {
                    throw ConfigurationError(
                        "\(error.localizedDescription) Restoring the previous borders "
                            + "also failed: \(failures.joined(separator: " ")). "
                            + "Apply borders again to recover.")
                }
                throw error
            }
        }
    }

    private static let cornerKey = "NSConvolutionOverride1"

    private static func validate(_ appearance: BorderAppearance) throws {
        guard appearance.width.isFinite, (0...16).contains(appearance.width),
            appearance.radius.map({ $0.isFinite && (0.3...12).contains($0) }) ?? true
        else { throw ConfigurationError("Border dimensions are outside the supported range") }
        guard
            appearance.excludedApps.allSatisfy({
                !$0.isEmpty && !$0.contains(",") && !$0.contains("\n") && !$0.contains("\r")
            })
        else {
            throw ConfigurationError(
                "Application names cannot be empty or contain commas or newlines.")
        }
    }

    private static func settingsValues(_ appearance: BorderAppearance) -> [String: String] {
        [
            "BORDER_RADIUS": appearance.radius.map { String($0) } ?? "system",
            "BORDER_WIDTH": String(format: "%.1f", appearance.width),
            "BORDER_STYLE": (appearance.radius ?? 12) < 1 ? "square" : "round",
            "BORDERS_VISIBLE": appearance.visible ? "true" : "false",
            "BORDERS_BLACKLIST": appearance.excludedApps.joined(separator: ",")
        ]
    }

    /// The global corner override before this edit, or `nil` when macOS chooses.
    /// Read before any write so a failed apply can put it back.
    private static func corners(_ integrations: Integrations) async throws -> String? {
        let current = await integrations.globalDefault(cornerKey)
        if current.ok {
            let value = current.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if Double(value) != nil { return value }
        } else if current.stderr.contains("does not exist") {
            return nil
        }
        throw ConfigurationError("Could not read window corners: \(current.summary)")
    }

    /// Sets or clears the corner override. Returns whether anything changed,
    /// so a later failure knows whether to put the old value back.
    private static func setCorners(
        _ radius: Double?, previous: String?, _ integrations: Integrations
    ) async throws -> Bool {
        let result: CommandResult
        if let radius {
            result = await integrations.setGlobalDefault(cornerKey, float: String(radius))
        } else if previous != nil {
            result = await integrations.removeGlobalDefault(cornerKey)
        } else {
            return false
        }
        guard result.ok else { throw ConfigurationError(result.summary) }
        return true
    }

    /// Puts the corner override back as it was. Returns why that failed, if it did.
    private static func restoreCorners(
        _ previous: String?, _ integrations: Integrations
    ) async -> String? {
        let restored =
            if let previous {
                await integrations.setGlobalDefault(cornerKey, float: previous)
            } else {
                await integrations.removeGlobalDefault(cornerKey)
            }
        return restored.ok ? nil : restored.summary
    }
}
