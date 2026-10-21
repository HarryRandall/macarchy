import Foundation
import Macarchy

// Mirrors `bridge/contract/rules.ts`.
struct RulesState: Codable, Sendable {
    let floatingApps: [String]
    let customRules: [CustomWindowRule]
    let externalRules: [WindowRuleSnapshot.External]
    let icons: [String: String]
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
