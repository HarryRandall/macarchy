import Foundation
import Testing
@testable import Macarchy

struct ThemeOutputsTests {
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appending(path: "fixtures/themes")
    @Test(arguments: [
        "awakening", "blackgold", "carbonfox", "city-783", "lumon", "matte-black", "midnight",
        "turbonite"
    ])
    func matchesOriginalShell(name: String) async throws {
        let directory = Self.fixtures.appending(path: name)
        let temporary = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-parity-\(UUID())")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let result = await CommandRunner.run(
            "/bin/bash",
            [Self.fixtures.appending(path: "reference.sh").path, directory.path, temporary.path])
        try #require(result.ok, "\(result.stderr)")
        let outputs = ThemeOutputs(
            theme: try Theme.read(from: directory),
            ghostty: try String(
                contentsOf: directory.appending(path: "ghostty.conf"), encoding: .utf8))
        #expect(
            outputs.btop
                == (try String(
                    contentsOf: temporary.appending(path: "active-theme.theme"), encoding: .utf8)))
        #expect(
            outputs.shell
                == (try String(contentsOf: temporary.appending(path: ".shell-env"), encoding: .utf8))
        )
        #expect(
            outputs.nvim + "\n"
                == (try String(contentsOf: temporary.appending(path: "nvim"), encoding: .utf8)))
    }
    @Test func rejectsInvalidThemeNamesAndColours() {
        #expect(throws: (any Error).self) { try Theme(name: "../escape").validate() }
        var theme = Theme(name: "valid")
        theme.colors.borderActive = "invalid"
        #expect(throws: (any Error).self) { try theme.validate() }
    }
}
