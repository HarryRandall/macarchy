import Foundation

/// What clicking a widget does. SketchyBar runs `macarchy widget click <id>`.
///
/// Opening something and running a command happen here, so they work even
/// when the app is not running. A dropdown needs the app to draw it, so the
/// command hands that to the app with a notification.
public enum WidgetActions {
    /// The notification the app answers by opening a widget's dropdown.
    public static let dropdownNotification = Notification.Name(
        "io.github.harryrandall.macarchy.widget.dropdown")
    public static let openTool = "/usr/bin/open"

    public enum Outcome: Equatable, Sendable {
        case opened(String)
        case ran(String)
        case dropdown(String)
        case nothing
    }

    public typealias Execute =
        @Sendable (
            _ executable: String, _ arguments: [String], _ environment: [String: String]?,
            _ directory: URL?
        ) async -> CommandResult

    static let defaultExecute: Execute = { executable, arguments, environment, directory in
        await CommandRunner.run(
            executable, arguments, environment: environment, directory: directory)
    }

    public static func click(
        _ instanceID: String, configuration: BarConfiguration?,
        catalogue: WidgetCatalogue.Snapshot, execute: Execute? = nil
    ) async throws -> Outcome {
        let execute = execute ?? defaultExecute
        let resolved = WidgetInstance.resolve(configuration, catalogue: catalogue)
        guard let instance = resolved.instances.first(where: { $0.id == instanceID }) else {
            throw ConfigurationError(
                resolved.problems[instanceID]
                    ?? "There is no widget called \(instanceID) on the bar")
        }
        guard let click = instance.click else { return .nothing }
        if click.dropdown != nil { return .dropdown(instanceID) }
        if let target = click.open {
            try await open(target, execute: execute)
            return .opened(target)
        }
        if let command = click.run {
            try await run(command, for: instance, execute: execute)
            return .ran(command)
        }
        return .nothing
    }

    /// Opens an app by name, or a URL such as a System Settings page.
    public static func open(_ target: String, execute: Execute? = nil) async throws {
        let result = await (execute ?? defaultExecute)(openTool, openArguments(target), nil, nil)
        guard result.ok else {
            throw ConfigurationError("Could not open \(target): \(result.stderr)")
        }
    }

    /// Runs a command as the person, from the widget's folder, with its settings.
    public static func run(
        _ command: String, for instance: WidgetInstance, execute: Execute? = nil
    ) async throws {
        let environment = WidgetProviderRunner.environment(
            instance: instance.id, widget: instance.manifest.id, settings: instance.settings)
        let result = await (execute ?? defaultExecute)(
            "/bin/sh", ["-c", command], environment, instance.directory)
        guard result.ok else { throw ConfigurationError(result.summary) }
    }

    /// A URL such as a System Settings page opens as a URL; anything else is
    /// an app name.
    static func openArguments(_ target: String) -> [String] {
        target.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil
            ? [target] : ["-a", target]
    }
}
