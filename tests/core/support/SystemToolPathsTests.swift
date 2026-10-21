import Foundation
import Testing

@testable import Macarchy

/// launchctl and defaults change the real login session and global domain
/// whatever the home is, so a run with its own search path must only ever
/// reach a fake. The environment is passed in rather than set: the web view
/// suites change `MACARCHY_SEARCH_PATH` for the whole test process.
@Suite("System tool paths")
struct SystemToolPathsTests {
    private struct Tool: Sendable {
        let name: String
        let system: String
        let resolve: @Sendable ([String: String]) -> String
    }

    private static let tools = [
        Tool(name: "launchctl", system: "/bin/launchctl") { Paths.launchctl(in: $0) },
        Tool(name: "defaults", system: "/usr/bin/defaults") { Paths.defaults(in: $0) }
    ]

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "system-tools-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("without a search path the real tools are used")
    func realTools() {
        for tool in Self.tools {
            #expect(tool.resolve([:]) == tool.system)
        }
    }

    @Test("a search path without a fake never falls back to the real tool")
    func missingFake() throws {
        let empty = try folder()
        defer { try? FileManager.default.removeItem(at: empty) }
        let environment = ["MACARCHY_SEARCH_PATH": empty.path]
        for tool in Self.tools {
            let path = tool.resolve(environment)
            #expect(path != tool.system)
            #expect(path == empty.appending(path: tool.name).path)
            #expect(!FileManager.default.fileExists(atPath: path))
        }
    }

    @Test("a fake on the search path is used, wherever it sits on it")
    func fakeOnSearchPath() throws {
        let first = try folder()
        let second = try folder()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let environment = ["MACARCHY_SEARCH_PATH": first.path + ":" + second.path]
        for tool in Self.tools {
            let fake = second.appending(path: tool.name)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: fake)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: fake.path)
            #expect(tool.resolve(environment) == fake.path)
        }
    }
}
