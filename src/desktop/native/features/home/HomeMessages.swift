import Foundation
import Macarchy

struct HomeState: Codable, Sendable {
    var theme: String?
    var themeCount: Int
    var shortcutsCount: Int
    var layout: String
    var running: Int
    var total: Int
    var lastChange: Double?
    var wallpaper: String?
    var subtitle: String

    private enum CodingKeys: String, CodingKey {
        case theme, themeCount, shortcutsCount, layout, running, total, lastChange, wallpaper,
            subtitle
    }

    func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(theme, forKey: .theme)
        try fields.encode(themeCount, forKey: .themeCount)
        try fields.encode(shortcutsCount, forKey: .shortcutsCount)
        try fields.encode(layout, forKey: .layout)
        try fields.encode(running, forKey: .running)
        try fields.encode(total, forKey: .total)
        try fields.encode(lastChange, forKey: .lastChange)
        try fields.encode(wallpaper, forKey: .wallpaper)
        try fields.encode(subtitle, forKey: .subtitle)
    }
}

extension BridgeEvent {
    static var homeChanged: BridgeEvent { BridgeEvent("home.changed") }
}
