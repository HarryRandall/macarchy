import Foundation
import Macarchy

// Mirrors bridge/contract/borders.ts.
struct BordersState: Encodable, Sendable {
    var appearance: BorderAppearance
    var applicationIcons: [String: String]
    var theme: String?
    var defaults: BorderAppearance?
    var unavailableReason: String?
    var wallpaper: String?

    private enum CodingKeys: String, CodingKey {
        case appearance, applicationIcons, theme, defaults, unavailableReason, wallpaper
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(applicationIcons, forKey: .applicationIcons)
        try container.encode(theme, forKey: .theme)
        try container.encode(defaults, forKey: .defaults)
        try container.encode(unavailableReason, forKey: .unavailableReason)
        try container.encode(wallpaper, forKey: .wallpaper)
    }
}

struct BordersApplyParams: Decodable {
    var appearance: BorderAppearance
    var theme: String
}

extension BridgeEvent {
    static func bordersChanged(_ state: BordersState) -> BridgeEvent {
        BridgeEvent("borders.changed", state: state)
    }
}
