import Foundation
import Macarchy

// Mirrors `src/desktop/ui/src/bridge/contract/shell.ts`.

struct ShellState: Codable, Sendable, Equatable {
    var selectedPane: String
    var sidebarVisible: Bool
    var setupRequired: Bool
    var appearance: Appearance
    var services: Services
    var version: String
    var serviceList: [Service]

    struct Appearance: Codable, Sendable, Equatable {
        var accent: String
        var mode: AppearanceMode
    }

    struct Services: Codable, Sendable, Equatable {
        var running: Int
        var total: Int
    }

    struct Service: Codable, Sendable, Equatable {
        enum State: String, Codable, Sendable {
            case running, stopped, unknown

            init(_ state: DaemonState?) {
                switch state ?? .unknown {
                case .running: self = .running
                case .stopped: self = .stopped
                case .unknown: self = .unknown
                }
            }
        }

        var id: ServiceParams.ServiceID
        var name: String
        var state: State
    }
}

enum AppearanceMode: String, Codable, Sendable {
    case system, light, dark
}

struct ShellPreferences: Codable, Sendable {
    var selectedPane: String?
    var sidebarVisible: Bool?
    var appearance: AppearanceMode?
}

struct OpenClassicParams: Codable, Sendable {
    enum Show: String, Codable, Sendable { case search, console }
    var pane: String?
    var show: Show?
}

struct TitlebarParams: Codable, Sendable {
    var height: Double
    var controls: [WebRect]
}

struct LogEntry: Codable, Sendable {
    var id: String
    var command: String
    var detail: String
    var ok: Bool
    /// Seconds since the Unix epoch.
    var at: Double
    var status: Int?
    var category: ConsoleCategory

    private enum CodingKeys: String, CodingKey {
        case id, command, detail, ok, at, status, category
    }

    func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(id, forKey: .id)
        try fields.encode(command, forKey: .command)
        try fields.encode(detail, forKey: .detail)
        try fields.encode(ok, forKey: .ok)
        try fields.encode(at, forKey: .at)
        try fields.encode(status, forKey: .status)
        try fields.encode(category, forKey: .category)
    }
}

extension ConsoleCategory: Codable {}

struct LogState: Codable, Sendable {
    var entries: [LogEntry]
}

struct RestartAllResult: Codable, Sendable {
    var outcome: String
}

extension BridgeEvent {
    static func shellChanged(_ state: ShellState) -> BridgeEvent {
        BridgeEvent("shell.changed", state: state)
    }

    /// Tells the page to read the log again.
    static var shellLogChanged: BridgeEvent { BridgeEvent("shell.logChanged") }
}
