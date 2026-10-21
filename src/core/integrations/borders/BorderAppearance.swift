import Foundation

/// A complete edit, kept separate from persisted settings until it is applied.
public struct BorderAppearance: Equatable, Sendable {
    public var width: Double = 6
    public var visible = true
    public var excludedApps = ["iPhone Mirroring"]
    public var radius: Double?
    public var activeColour: String?
    public var inactiveColour: String?

    public init() {}

    /// System-managed corners have no numeric override. This is only a preview approximation.
    public var previewRadius: Double { radius ?? 12 }
}
