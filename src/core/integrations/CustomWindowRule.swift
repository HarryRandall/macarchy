import Foundation

/// A user-created floating rule. App names are literal; titles are optional patterns.
public struct CustomWindowRule: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var app: String
    public var title: String

    public init(id: String = UUID().uuidString, app: String, title: String = "") {
        self.id = id
        self.app = app.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func validate() throws {
        guard UUID(uuidString: id) != nil else {
            throw ConfigurationError("Invalid rule identifier")
        }
        guard !app.isEmpty, !app.contains("\n"), !app.contains("\0") else {
            throw ConfigurationError("Enter an application name")
        }
        guard !title.contains("\n"), !title.contains("\0") else {
            throw ConfigurationError("Window title must be a single-line pattern")
        }
        if !title.isEmpty, !Self.compilesAsExtendedRegex(title) {
            throw ConfigurationError(
                "Invalid window title pattern. Use a POSIX extended regular expression.")
        }
    }

    /// yabai compiles rule patterns with the system `regcomp` and `REG_EXTENDED`,
    /// so validating the same way accepts exactly what yabai will accept.
    static func compilesAsExtendedRegex(_ pattern: String) -> Bool {
        var regex = regex_t()
        guard regcomp(&regex, pattern, REG_EXTENDED | REG_NOSUB) == 0 else { return false }
        regfree(&regex)
        return true
    }

    public var arguments: [String] {
        var values = [
            "-m", "rule", "--add", "app=^\(NSRegularExpression.escapedPattern(for: app))$",
            "manage=off", "label=macarchy_custom_\(id)"
        ]
        if !title.isEmpty { values.append("title=\(title)") }
        return values
    }
}
