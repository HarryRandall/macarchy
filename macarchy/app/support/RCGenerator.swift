import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class RCGenerator {
    private(set) var lastOutcomes: [String: GeneratedFile.Outcome] = [:]
    private let log: CommandLog
    private let configuration = StartupConfiguration()
    init(log: CommandLog) { self.log = log }
    static func envName(forYabaiKey key: String) -> String? {
        StartupConfiguration.envName(forYabaiKey: key)
    }
    static func envName(forBarKey key: String) -> String? {
        StartupConfiguration.envName(forBarKey: key)
    }
    func generateBordersRC() { record("bordersrc", configuration.generateBordersRC()) }
    func generateYabaiRC() { record("yabairc", configuration.generateYabaiRC()) }
    func generateSketchybarRC() { record("sketchybarrc", configuration.generateSketchybarRC()) }
    private func record(_ name: String, _ outcome: GeneratedFile.Outcome) {
        lastOutcomes[name] = outcome
        if case .failed(let message) = outcome { log.failure(name, message) }
    }
}
