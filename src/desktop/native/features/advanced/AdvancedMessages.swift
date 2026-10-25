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
    var loginItem: LoginItem.State
}

struct ServiceParams: Codable, Sendable {
    enum ServiceID: String, Codable, Sendable {
        case yabai, borders, sketchybar, skhd
        init(_ daemon: Daemon) {
            switch daemon {
            case .yabai: self = .yabai
            case .borders: self = .borders
            case .sketchybar: self = .sketchybar
            case .skhd: self = .skhd
            }
        }
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
struct LoginItemParams: Codable, Sendable { var enabled: Bool }
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
    /// What moving an earlier version's folder did, until setup reports it.
    var notices: [String]
}
struct SetupReport: Codable, Sendable {
    var lines: [String]
    var failures: [String]
    /// Why setup stopped early. `lines` still lists what it changed first.
    var failure: String?
}

extension SetupReport {
    private enum CodingKeys: String, CodingKey { case lines, failures, failure }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lines, forKey: .lines)
        try container.encode(failures, forKey: .failures)
        try container.encode(failure, forKey: .failure)
    }
}

struct CleanupPlanState: Codable, Sendable {
    struct Section: Codable, Sendable {
        struct Line: Codable, Sendable {
            var path: String
            var detail: String
        }
        var title: String
        var lines: [Line]
    }
    var sections: [Section]
    var hasChanges: Bool
    var refusal: String?

    private enum CodingKeys: String, CodingKey { case sections, hasChanges, refusal }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sections, forKey: .sections)
        try container.encode(hasChanges, forKey: .hasChanges)
        try container.encode(refusal, forKey: .refusal)
    }
}

struct CleanupReport: Codable, Sendable {
    var lines: [String]
    var failures: [String]
    var failure: String?
    var archive: String?

    private enum CodingKeys: String, CodingKey { case lines, failures, failure, archive }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lines, forKey: .lines)
        try container.encode(failures, forKey: .failures)
        try container.encode(failure, forKey: .failure)
        try container.encode(archive, forKey: .archive)
    }
}

extension BridgeEvent {
    static func advancedChanged(_ state: AdvancedState) -> BridgeEvent {
        BridgeEvent("advanced.changed", state: state)
    }

    /// Tells the page to read its state again.
    static var advancedInvalidated: BridgeEvent { BridgeEvent("advanced.invalidated") }
}
