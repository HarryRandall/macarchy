import Foundation

/// One daemon setting the app owns: what the daemon calls it, the settings.env
/// variable the generated rc resolves it from, and what applies if nothing has
/// been set yet.
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
