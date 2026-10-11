import Foundation

/// Explicit retirement of two old startup defaults. This never runs on page load.
public enum LegacyWindowRules {
    private static let definitions: Set<String> = [
        "yabai -m rule --add app=\"^Calculator$\" manage=off",
        "yabai -m rule --add app=\"^Finder$\" manage=off title=\"^Copy$|^Move$|^Delete$|^Trash$\""
    ]

    public static func removingDefaults(from text: String) -> String {
        text.components(separatedBy: "\n")
            .filter { !definitions.contains($0.trimmingCharacters(in: .whitespaces)) }
            .joined(separator: "\n")
    }

    public static func retire(
        file: GeneratedFile = StartupConfiguration.yabairc,
        integrations: Integrations = Integrations()
    ) async throws {
        try await OperationLock.run(root: file.ledgerURL.deletingLastPathComponent()) {
            let original = try String(contentsOf: file.url, encoding: .utf8)
            let response = await integrations.yabaiRules()
            guard response.ok else { throw ConfigurationError(response.summary) }
            struct Rule: Decodable {
                let index: Int
                let label: String
                let app: String
                let title: String
                let manage: Bool
                let space: Int
                let grid: String
            }
            let rules = try JSONDecoder().decode([Rule].self, from: Data(response.stdout.utf8))
            let retired = rules.filter {
                $0.label.isEmpty && !$0.manage && $0.space == 0 && $0.grid == "0:0:0:0:0:0"
                    && (($0.app == "^Calculator$" && $0.title.isEmpty)
                        || ($0.app == "^Finder$" && $0.title == "^Copy$|^Move$|^Delete$|^Trash$"))
            }
            let outcome = file.write(
                removingDefaults(from: original), reason: "optional window rules")
            if case .failed(let message) = outcome { throw ConfigurationError(message) }
            for rule in retired.sorted(by: { $0.index > $1.index }) {
                let result = await integrations.execute(
                    Paths.yabai, ["-m", "rule", "--remove", String(rule.index)])
                guard result.ok else { throw ConfigurationError(result.summary) }
            }
        }
    }
}
