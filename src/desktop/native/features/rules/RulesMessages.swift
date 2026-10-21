import Foundation
import Macarchy

// Mirrors `bridge/contract/rules.ts`.
struct RulesState: Codable, Sendable {
    let floatingApps: [String]
    let customRules: [CustomWindowRule]
    let externalRules: [WindowRuleSnapshot.External]
    let icons: [String: String]
    let unavailableReason: String?

    private enum CodingKeys: String, CodingKey {
        case floatingApps, customRules, externalRules, icons, unavailableReason
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(floatingApps, forKey: .floatingApps)
        try container.encode(customRules, forKey: .customRules)
        try container.encode(externalRules, forKey: .externalRules)
        try container.encode(icons, forKey: .icons)
        try container.encode(unavailableReason, forKey: .unavailableReason)
    }
}

struct RemoveFloatingParams: Codable, Sendable { let app: String }
struct SaveRuleParams: Codable, Sendable { let rule: CustomWindowRule }
struct RemoveRuleParams: Codable, Sendable { let id: String }

struct RulesUnavailable: Codable, Sendable { let message: String }

extension BridgeEvent {
    static func rulesUnavailable(_ message: String) -> BridgeEvent {
        BridgeEvent("rules.unavailable", state: RulesUnavailable(message: message))
    }

    static func rulesChanged(_ state: RulesState) -> BridgeEvent {
        BridgeEvent("rules.changed", state: state)
    }
}
