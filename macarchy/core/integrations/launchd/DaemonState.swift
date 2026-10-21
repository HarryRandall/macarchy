import Foundation

public enum DaemonState: Equatable, Sendable {
    case running(pid: Int)
    case stopped
    case unknown

    public var isRunning: Bool { if case .running = self { true } else { false } }

    public var label: String {
        switch self {
        case .running(let pid): "running · \(pid)"
        case .stopped: "stopped"
        case .unknown: "unknown"
        }
    }
}
