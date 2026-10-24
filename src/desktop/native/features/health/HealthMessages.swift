import Foundation
import Macarchy

struct HealthState: Codable, Sendable {
    struct Check: Codable, Sendable {
        var id: String
        var group: String
        var title: String
        var status: String
        var detail: String
        var fix: String?

        private enum CodingKeys: String, CodingKey { case id, group, title, status, detail, fix }

        func encode(to encoder: Encoder) throws {
            var fields = encoder.container(keyedBy: CodingKeys.self)
            try fields.encode(id, forKey: .id)
            try fields.encode(group, forKey: .group)
            try fields.encode(title, forKey: .title)
            try fields.encode(status, forKey: .status)
            try fields.encode(detail, forKey: .detail)
            try fields.encode(fix, forKey: .fix)
        }
    }

    struct Machine: Codable, Sendable {
        var model: String
        var architecture: String
        var macOS: String
        var app: String
        var settingsFolder: String
    }

    var checks: [Check]
    var environment: Machine
    var checkedAt: Double

    init(_ snapshot: DiagnosticSnapshot) {
        checks = snapshot.checks.map {
            Check(
                id: $0.id, group: $0.group.rawValue, title: $0.title,
                status: $0.status.rawValue, detail: $0.detail, fix: $0.command ?? $0.fix)
        }
        let facts = snapshot.environment
        environment = Machine(
            model: facts.model, architecture: facts.architecture,
            macOS: facts.macOS, app: facts.app,
            settingsFolder: Paths.display(Paths.appRoot))
        checkedAt = snapshot.checkedAt.timeIntervalSince1970
    }
}

struct HealthFixParams: Decodable { var id: String }

extension BridgeEvent {
    static var healthChanged: BridgeEvent { BridgeEvent("health.changed") }
}
