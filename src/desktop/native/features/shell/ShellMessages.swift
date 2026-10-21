import Foundation

// Mirrors `src/desktop/ui/src/bridge/contract/shell.ts`.

struct ShellState: Codable, Sendable, Equatable {
    var selectedPane: String
    var sidebarVisible: Bool
    var setupRequired: Bool
    var appearance: Appearance
    var services: Services

    struct Appearance: Codable, Sendable, Equatable {
        var accent: String
    }

    struct Services: Codable, Sendable, Equatable {
        var running: Int
        var total: Int
    }
}

struct ShellPreferences: Codable, Sendable {
    var selectedPane: String?
    var sidebarVisible: Bool?
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

extension BridgeEvent {
    static func shellChanged(_ state: ShellState) -> BridgeEvent {
        BridgeEvent("shell.changed", state: state)
    }
}
