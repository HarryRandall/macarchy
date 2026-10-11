import Foundation
import IOKit

/// A problem report a person can read in full before sharing it.
///
/// Only structured facts go in: versions, health check results and the Mac's
/// model. The username, full name, computer name and home path are replaced
/// wherever they appear, and no logs, configuration or window titles are
/// included. Arbitrary text can never be guaranteed anonymous, so the report
/// is always shown before it leaves the app.
public enum Diagnostics {
    /// Where reports are filed. One place, so a fork changes one line.
    public static let repository = URL(string: "https://github.com/HarryRandall/macarchy")!

    public struct Environment: Sendable {
        public var app: String
        public var macOS: String
        public var model: String
        public var architecture: String
        public var tools: [(String, String)]
    }

    public static func environment(integrations: Integrations = Integrations()) async -> Environment
    {
        let info = ProcessInfo.processInfo
        let version = info.operatingSystemVersion
        var tools: [(String, String)] = []
        for name in ["yabai", "skhd", "sketchybar", "borders"] {
            guard Paths.isInstalled(name) else {
                tools.append((name, "not installed"))
                continue
            }
            let result = await integrations.execute(Paths.executable(name), ["--version"])
            let firstLine = result.stdout.split(separator: "\n").first.map(String.init)
            tools.append((name, result.ok ? firstLine ?? "installed" : "installed"))
        }
        let bundle = Bundle.main.infoDictionary
        let app = [bundle?["CFBundleShortVersionString"], bundle?["CFBundleVersion"]]
            .compactMap { $0 as? String }.joined(separator: " build ")
        return Environment(
            app: app.isEmpty ? "development build" : app,
            macOS: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            model: modelName(),
            architecture: architecture(),
            tools: tools)
    }

    /// The report body, in Markdown, already redacted.
    public static func report(
        title: String, description: String, environment: Environment, checks: [HealthCheck]
    ) -> String {
        var lines = ["## What happened", "", description.isEmpty ? "_Not described_" : description]
        lines += ["", "## Environment", ""]
        lines.append("- Macarchy: \(environment.app)")
        lines.append("- macOS: \(environment.macOS)")
        lines.append("- Mac: \(environment.model) (\(environment.architecture))")
        for (tool, version) in environment.tools { lines.append("- \(tool): \(version)") }
        let notable = checks.filter { $0.status != .passed }
        lines += ["", "## Checks", ""]
        if notable.isEmpty {
            lines.append("All \(checks.count) checks passed.")
        } else {
            for check in notable {
                let detail = check.detail.isEmpty ? "" : ": \(check.detail)"
                lines.append(
                    "- \(check.status.rawValue) · \(check.group.rawValue) · \(check.title)\(detail)"
                )
            }
        }
        return redact(lines.joined(separator: "\n"))
    }

    /// Replaces the identifying strings this Mac would otherwise leak.
    public static func redact(_ text: String) -> String {
        var output = text
        let replacements: [(String, String)] = [
            (Paths.home.path, "~"),
            (NSHomeDirectory(), "~"),
            (NSFullUserName(), "<name>"),
            (Host.current().localizedName ?? "", "<computer>"),
            (NSUserName(), "<user>")
        ]
        // Longest first, so a home path is replaced before the username inside it.
        for (secret, replacement) in replacements.sorted(by: { $0.0.count > $1.0.count })
        where secret.count >= 3 {
            output = output.replacingOccurrences(of: secret, with: replacement)
        }
        return output
    }

    /// A prefilled "new issue" link. GitHub documents no length limit, so a
    /// conservative budget keeps the URL working; over it, the person pastes.
    public static func issueURL(title: String, body: String, budget: Int = 8000) -> URL? {
        var components = URLComponents(
            url: repository.appending(path: "issues/new"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "title", value: title), URLQueryItem(name: "body", value: body)
        ]
        guard let url = components?.url, url.absoluteString.utf8.count <= budget else { return nil }
        return url
    }

    // MARK: - Hardware

    /// The marketing name, such as "MacBook Pro (14-inch, 2024)", from the
    /// device tree. Falls back to the model identifier where it is absent.
    public static func modelName() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        defer { IOObjectRelease(entry) }
        if entry != 0,
            let property = IORegistryEntryCreateCFProperty(
                entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data
        {
            let name = String(bytes: property.prefix { $0 != 0 }, encoding: .utf8) ?? ""
            if !name.isEmpty { return name }
        }
        return hardwareModel()
    }

    public static func hardwareModel() -> String { sysctl("hw.model") ?? "Mac" }

    static func architecture() -> String {
        sysctl("hw.optional.arm64") == nil ? "Intel" : "Apple Silicon"
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        let value = String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        return value.isEmpty ? nil : value
    }
}
