import Foundation

/// What `launchctl print` says launchd holds for a job.
///
/// The format is meant for people, so this reads only the lines it needs and
/// treats anything it cannot find as missing. A definition that reads as
/// missing never matches an agent, which costs a reload rather than leaving
/// a stale job running.
struct LoadedJob: Equatable {
    /// The parts of a job that Macarchy's agents set and launchd reports.
    struct Definition: Equatable {
        var arguments: [String]
        var path: String?
        var standardOut: String?
        var standardError: String?
    }

    var arguments: [String] = []
    var environment: [String: String] = [:]
    var standardOut: String?
    var standardError: String?
    var running = false

    /// `launchctl print` puts each argument and each environment variable on
    /// its own line inside `arguments = {` and `environment = {` blocks; the
    /// `inherited environment` and `default environment` blocks are not the
    /// job's own.
    init(_ description: String) {
        var block: String?
        for raw in description.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let current = block {
                if line == "}" {
                    block = nil
                } else if current == "arguments" {
                    arguments.append(line)
                } else if current == "environment", let split = line.range(of: " => ") {
                    environment[String(line[..<split.lowerBound])] = String(
                        line[split.upperBound...])
                }
                continue
            }
            switch line {
            case "arguments = {": block = "arguments"
            case "environment = {": block = "environment"
            case "state = running": running = true
            default:
                if line.hasPrefix("stdout path = ") {
                    standardOut = String(line.dropFirst("stdout path = ".count))
                } else if line.hasPrefix("stderr path = ") {
                    standardError = String(line.dropFirst("stderr path = ".count))
                }
            }
        }
    }

    /// Nil when launchd reported no arguments, so it cannot match an agent.
    var definition: Definition? {
        guard !arguments.isEmpty else { return nil }
        return Definition(
            arguments: arguments, path: environment["PATH"], standardOut: standardOut,
            standardError: standardError)
    }
}
