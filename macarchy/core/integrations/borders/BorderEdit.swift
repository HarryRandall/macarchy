import Foundation

public enum BorderEdit {
    public static func apply(
        _ appearance: BorderAppearance, directory: URL, integrations: Integrations = Integrations()
    ) async throws {
        try await OperationLock.run {
            guard appearance.width.isFinite, (0...16).contains(appearance.width),
                appearance.radius.map({ $0.isFinite && (0.3...12).contains($0) }) ?? true
            else { throw ConfigurationError("Border dimensions are outside the supported range") }
            let store = SettingsStore()
            _ = try store.read()
            var theme = try Theme.read(from: directory)
            theme.colors.borderActive = appearance.activeColour
            theme.colors.borderInactive = appearance.inactiveColour
            try theme.validate()
            let values = [
                "BORDER_RADIUS": appearance.radius.map { String($0) } ?? "system",
                "BORDER_WIDTH": String(format: "%.1f", appearance.width),
                "BORDER_STYLE": (appearance.radius ?? 12) < 1 ? "square" : "round",
                "BORDERS_VISIBLE": appearance.visible ? "true" : "false",
                "BORDERS_BLACKLIST": appearance.excludedApps.joined(separator: ",")
            ]
            let original = try Theme.read(from: directory)
            if original != theme {
                try SnapshotStore().capture(
                    [directory.appending(path: Theme.fileName)], reason: "border colours")
            }
            let radius: CommandResult
            if let value = appearance.radius {
                radius = await integrations.setGlobalDefault(
                    "NSConvolutionOverride1", float: String(value))
            } else {
                let current = await integrations.globalDefault("NSConvolutionOverride1")
                radius =
                    !current.ok && current.stderr.contains("does not exist")
                    ? CommandResult(command: "corners", status: 0)
                    : await integrations.removeGlobalDefault("NSConvolutionOverride1")
            }
            guard radius.ok else { throw ConfigurationError(radius.summary) }
            let result = await integrations.borders(
                BorderCommand.arguments(values: values, theme: theme))
            guard result.ok else { throw ConfigurationError(result.summary) }
            if original != theme { try theme.write(to: directory) }
            try store.write(values)
        }
    }
}
