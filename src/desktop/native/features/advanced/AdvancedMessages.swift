import Foundation
import Macarchy

// Mirrors bridge/contract/advanced.ts.
struct AdvancedState: Codable, Sendable {
    struct Service: Codable, Sendable {
        var id: String
        var state: String
    }
    struct Snapshot: Codable, Sendable {
        var id: String
        var created: Double
        var files: Int
        var reason: String
    }
    var services: [Service]
    var snapshots: [Snapshot]
    var theme: String
    var installedThemes: Int
    var addition: String
    var additionExplanation: String
    var wakeHelpers: Bool
    var backupsDirectory: String
}

struct ServiceParams: Codable, Sendable {
    enum ServiceID: String, Codable, Sendable {
        case yabai, borders, sketchybar, skhd
        var daemon: Daemon {
            switch self {
            case .yabai: .yabai
            case .borders: .borders
            case .sketchybar: .sketchybar
            case .skhd: .skhd
            }
        }
    }
    var daemon: ServiceID
}
struct RebuildParams: Codable, Sendable { var file: AdvancedConfiguration.File }
struct SnapshotParams: Codable, Sendable { var id: String }
struct RebuildResult: Codable, Sendable { var outcome: String }
struct SetupParams: Codable, Sendable {
    enum Existing: String, Codable, Sendable { case keep, replace }
    var existing: Existing
}
struct SetupState: Codable, Sendable {
    struct Tool: Codable, Sendable {
        var id: String
        var name: String
        var role: String
        var installed: Bool
        var installCommand: String
    }
    struct Change: Codable, Sendable {
        var path: String
        var action: String
        var detail: String
    }
    var tools: [Tool]
    var changes: [Change]
    var hasExisting: Bool
    var canClose: Bool
}
struct SetupReport: Codable, Sendable {
    var lines: [String]
    var failures: [String]
}

extension BridgeEvent {
    static func advancedChanged(_ state: AdvancedState) -> BridgeEvent {
        BridgeEvent("advanced.changed", state: state)
    }
}
