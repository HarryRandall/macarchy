import Foundation

/// A complete edit, kept separate from persisted settings until it is applied.
public struct BorderAppearance: Codable, Equatable, Sendable {
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

extension BorderAppearance {
    private enum CodingKeys: String, CodingKey {
        case width, visible, excludedApps, radius, activeColour, inactiveColour
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(visible, forKey: .visible)
        try container.encode(excludedApps, forKey: .excludedApps)
        try container.encode(radius, forKey: .radius)
        try container.encode(activeColour, forKey: .activeColour)
        try container.encode(inactiveColour, forKey: .inactiveColour)
    }
}
