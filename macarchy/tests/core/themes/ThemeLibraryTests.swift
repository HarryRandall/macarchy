import Foundation
import Testing
@testable import Macarchy

struct ThemeLibraryTests {
    @Test func invalidManifestIsNeverReconstructedFromEnv() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-theme-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "invalid".write(
            to: root.appending(path: "theme.json"), atomically: true, encoding: .utf8)
        try "DARK_MODE=true\n".write(
            to: root.appending(path: "theme.env"), atomically: true, encoding: .utf8)
        #expect(throws: (any Error).self) { try Theme.read(from: root) }
        #expect(
            try String(contentsOf: root.appending(path: "theme.json"), encoding: .utf8) == "invalid"
        )
    }
    @Test func rejectsSymlinkAssetsWithoutInstallingPartialPackage() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "macarchy-import-\(UUID())")
        let source = root.appending(path: "source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Theme(name: "example").write(to: source)
        try FileManager.default.createSymbolicLink(
            atPath: source.appending(path: "outside.conf").path, withDestinationPath: "/etc/hosts")
        let library = ThemeLibrary(root: root.appending(path: "installed"))
        #expect(throws: (any Error).self) { try library.importTheme(from: source) }
        #expect(
            !FileManager.default.fileExists(atPath: library.root.appending(path: "example").path))
    }
    @Test func paletteIgnoresNonColourValues() {
        let outputs = ThemeOutputs(
            theme: Theme(name: "example"), ghostty: "palette = 4=not-a-colour\n")
        #expect(outputs.palette(4, fallback: "#ffffff") == "#ffffff")
    }
}
