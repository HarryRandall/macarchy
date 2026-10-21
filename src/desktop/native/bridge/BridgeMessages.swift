import Foundation
import Macarchy

// The shared half of the bridge contract, mirroring
// `src/desktop/ui/src/bridge/protocol.ts`. Each feature's messages live with it
// (`native/features/<feature>`, `native/switcher`), mirroring
// `bridge/contract/<feature>.ts` exactly; change both together.

enum Surface: String, Codable, Sendable {
    case settings, switcher
}

struct Empty: Codable, Sendable {}

/// Encodes as JSON `null`, for requests that return nothing.
struct Null: Codable, Sendable {
    init() {}
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

struct WebRect: Codable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct ReadyParams: Codable, Sendable {
    var surface: Surface
}

/// An event for the page, sent as `{ type, state }`. Each feature declares its
/// events as static constructors beside its messages.
struct BridgeEvent: Encodable, Sendable {
    let type: String
    let state: (any Encodable & Sendable)?

    init(_ type: String, state: (any Encodable & Sendable)? = nil) {
        self.type = type
        self.state = state
    }

    private enum Keys: String, CodingKey { case type, state }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(type, forKey: .type)
        if let state { try container.encode(state, forKey: .state) }
    }
}
