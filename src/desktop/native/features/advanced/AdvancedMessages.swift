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
    /// Whether the trackpad's sideways swipe switches Spaces at once.
    var trackpadSwipes: Bool
    /// Tools Macarchy installed with Homebrew and still there, which
    /// restoring may also remove.
    var removableTools: [RemovableTool]
}
struct RemovableTool: Codable, Sendable {
    var id: String
    var name: String
}
struct RestoreParams: Codable, Sendable {
    /// Ids from `AdvancedState.removableTools` to remove with Homebrew.
    var removeTools: [String]
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
struct TrackpadSwipesParams: Codable, Sendable { var enabled: Bool }
struct SetupParams: Codable, Sendable {
    enum Existing: String, Codable, Sendable { case keep, replace }
    /// The tools to configure; the others are left alone.
    var tools: [ServiceParams.ServiceID]
    /// How each tool with a config of its own starts, by tool id; `keep`
    /// for any not given.
    var existing: [String: Existing]
    /// Ids of the extras to set up; none when not given.
    var extras: [String]?

    var choices: Setup.Choices {
        var existing: [Daemon: Setup.Existing] = [:]
        for (id, choice) in self.existing {
            guard let daemon = Daemon(rawValue: id) else { continue }
            existing[daemon] = choice == .keep ? .keep : .replace
        }
        return Setup.Choices(
            tools: Set(tools.map(\.daemon)), existing: existing, extras: Set(extras ?? []))
    }
}
struct SetupState: Codable, Sendable {
    struct Tool: Codable, Sendable {
        var id: String
        var name: String
        var description: String
        var installed: Bool
        /// Ticked to begin with: chosen in the last setup, or every tool
        /// before the first.
        var chosen: Bool
        /// The person's own config the tool can start from, home-relative.
        var ownConfig: String?

        private enum CodingKeys: String, CodingKey {
            case id, name, description, installed, chosen, ownConfig
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            try container.encode(installed, forKey: .installed)
            try container.encode(chosen, forKey: .chosen)
            try container.encode(ownConfig, forKey: .ownConfig)
        }
    }
    struct Change: Codable, Sendable {
        var path: String
        var action: String
        var detail: String
    }
    /// An app setup can install, which Macarchy uses when it is there.
    struct Extra: Codable, Sendable {
        var id: String
        var name: String
        var description: String
        var installed: Bool
    }
    var tools: [Tool]
    var extras: [Extra]
    /// Whether Homebrew is installed, so setup can install missing tools.
    var homebrew: Bool
    var changes: [Change]
    var canClose: Bool
}

/// One step of installing tools during setup, sent as it happens.
struct SetupProgress: Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case installing, output, installed, failed, configuring
    }
    /// The tool being installed, or nil once setup moves on to its files.
    var tool: String?
    var status: Status
    /// A line of Homebrew's output, or why installing failed.
    var line: String?

    private enum CodingKeys: String, CodingKey { case tool, status, line }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tool, forKey: .tool)
        try container.encode(status, forKey: .status)
        try container.encode(line, forKey: .line)
    }
}

extension SetupProgress {
    init(_ step: SetupSession.Step) {
        switch step {
        case .configuring: self.init(tool: nil, status: .configuring, line: nil)
        case .homebrew(.started(let package)):
            self.init(tool: package.id, status: .installing, line: nil)
        case .homebrew(.output(let package, let line)):
            self.init(tool: package.id, status: .output, line: line)
        case .homebrew(.finished(let package)):
            self.init(tool: package.id, status: .installed, line: nil)
        case .homebrew(.failed(let package, let reason)):
            self.init(tool: package.id, status: .failed, line: reason)
        }
    }
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

extension BridgeEvent {
    static func advancedChanged(_ state: AdvancedState) -> BridgeEvent {
        BridgeEvent("advanced.changed", state: state)
    }

    /// Tells the page to read its state again.
    static var advancedInvalidated: BridgeEvent { BridgeEvent("advanced.invalidated") }

    static func setupProgress(_ progress: SetupProgress) -> BridgeEvent {
        BridgeEvent("setup.progress", state: progress)
    }
}
