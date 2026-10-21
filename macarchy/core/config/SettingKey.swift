import Foundation

/// Maps an integration key to the legacy import key and its startup default.
public struct SettingKey: Sendable {
    public let key: String
    public let env: String
    public let fallback: String

    public init(key: String, env: String, fallback: String) {
        self.key = key
        self.env = env
        self.fallback = fallback
    }
}
