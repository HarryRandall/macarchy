import Foundation

/// One daemon setting the app owns: what the daemon calls it, the settings.env
/// variable the generated rc resolves it from, and what applies if nothing has
/// been set yet.
struct ConfigKey: Sendable {
    let key: String
    let env: String
    let fallback: String
}
