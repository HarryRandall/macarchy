import Foundation
import Macarchy

// Mirrors `src/desktop/ui/src/bridge/contract/layout.ts`.

struct LayoutState: Codable, Sendable, Equatable {
    var values: LayoutValues
    var source: String
    var unavailableReason: String?
    var wallpaper: String?

    init(_ snapshot: LayoutSnapshot, wallpaper: String?) {
        values = snapshot.values
        source = snapshot.source.rawValue
        unavailableReason = snapshot.unavailableReason
        self.wallpaper = wallpaper
    }
}

struct LayoutApplyParams: Codable, Sendable {
    var changes: LayoutChanges
    var linkPadding: Bool
}

// Synthesised encoding leaves nil optionals out; the contract declares them as
// `T | null`, so these spell them out.

extension LayoutState {
    private enum CodingKeys: String, CodingKey { case values, source, unavailableReason, wallpaper }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values, forKey: .values)
        try container.encode(source, forKey: .source)
        try container.encode(unavailableReason, forKey: .unavailableReason)
        try container.encode(wallpaper, forKey: .wallpaper)
    }
}

extension BridgeEvent {
    /// Layout changed somewhere else: the CLI, the classic window, a reload.
    static func layoutChanged(_ state: LayoutState) -> BridgeEvent {
        BridgeEvent("layout.changed", state: state)
    }
}
