import Foundation

/// Runs a widget's `provider.sh` and reads what it printed.
///
/// The script runs as the person, from its own folder, with a fixed `PATH`
/// that includes Homebrew and with each setting in the environment as
/// `MACARCHY_SETTING_<NAME>`. It gets a few seconds; one that hangs is
/// stopped, and the bar keeps the last thing it showed.
public struct WidgetProviderRunner: Sendable {
    public typealias Execute =
        @Sendable (
            _ executable: String, _ environment: [String: String], _ directory: URL,
            _ timeout: TimeInterval
        ) async -> CommandResult

    public static let path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    public let timeout: TimeInterval
    private let execute: Execute

    public init(timeout: TimeInterval = 5, execute: Execute? = nil) {
        self.timeout = timeout
        self.execute =
            execute ?? { executable, environment, directory, timeout in
                await CommandRunner.run(
                    executable, [], timeout: timeout, environment: environment,
                    directory: directory)
            }
    }

    public enum Failure: Error, Equatable, Sendable, CustomStringConvertible {
        case timedOut(seconds: Int)
        case failed(status: Int32, message: String)

        public var description: String {
            switch self {
            case .timedOut(let seconds): "took longer than \(seconds) seconds and was stopped"
            case .failed(let status, let message):
                message.isEmpty ? "stopped with status \(status)" : message
            }
        }
    }

    public func run(
        provider: String, in directory: URL, instance: String, widget: String,
        settings: [String: SettingValue]
    ) async -> Result<WidgetOutput, Failure> {
        let environment = Self.environment(instance: instance, widget: widget, settings: settings)
        let result = await execute(
            directory.appending(path: provider).path, environment, directory, timeout)
        if result.status == -1, result.stderr.hasPrefix("Timed out") {
            return .failure(.timedOut(seconds: Int(timeout)))
        }
        guard result.ok else {
            let first = result.stderr.split(whereSeparator: \.isNewline).first.map(String.init)
            return .failure(.failed(status: result.status, message: first ?? ""))
        }
        return .success(WidgetOutput.parse(result.stdout))
    }

    /// What the provider sees. Only what it needs: no inherited secrets from
    /// whatever started the app.
    static func environment(
        instance: String, widget: String, settings: [String: SettingValue],
        inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = [
            "PATH": path, "HOME": inherited["HOME"] ?? NSHomeDirectory(),
            "MACARCHY_WIDGET": widget, "MACARCHY_INSTANCE": instance
        ]
        for key in ["LANG", "LC_ALL", "TMPDIR", "USER"] {
            if let value = inherited[key] { environment[key] = value }
        }
        for (key, value) in settings {
            environment["MACARCHY_SETTING_\(screamingSnake(key))"] = value.string
        }
        return environment
    }

    /// `twentyFourHour` as `TWENTY_FOUR_HOUR`.
    static func screamingSnake(_ name: String) -> String {
        var result = ""
        for character in name {
            if character.isUppercase, !result.isEmpty { result += "_" }
            result += character.uppercased()
        }
        return result
    }
}
