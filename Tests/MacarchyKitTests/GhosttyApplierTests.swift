import Foundation
import Testing

@testable import MacarchyKit

/// The port is only trustworthy if it still matches the shell it replaced, so
/// these run the original awk|grep pipeline (kept verbatim as reference.sh) and
/// diff it against the Swift for the inputs most likely to diverge.
@Suite("GhosttyApplier vs the shell it replaced")
struct GhosttyApplierTests {
    static let reference = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "GhosttyPort/reference.sh")

    static let themeConf = """
        background = #0A1622
        foreground = #E4EDF5
        palette = 0=#000000
        palette = 4=#66CCFF
        """

    /// Inputs chosen for the ways the pipeline can differ: blank-run handling
    /// (the awk drops trailing but keeps interior), whitespace around keys, an
    /// existing theme marker, and near-miss keys such as background-opacity that
    /// a naive prefix match would eat.
    static let cases: [(name: String, config: String)] = [
        ("trailing-blanks", "font-size = 13\n\n\n\nwindow-padding-x = 8\n\n\n"),
        ("interior-blanks", "a = 1\n\nb = 2\n\n\nc = 3\n"),
        ("colour-lines", "background = #111111\nfont-size = 13\npalette = 0=#000000\ntheme = foo\n"),
        ("whitespace", "  background   =   #111111\n\tforeground=#fff\nfont-size = 13\n"),
        ("config-file-refs", "config-file = ~/.themes/x.conf\nconfig-file = ~/o/y.conf\nfont=13\n"),
        ("existing-marker", "font-size = 13\n# --- THEME COLORS (old) ---\nbackground = #999\n"),
        ("empty", ""),
        ("near-miss-keys", "backgroundish = 1\nforegrounds = 2\nbackground-opacity = 0.9\n"),
    ]

    @Test("matches the shell", arguments: cases)
    func matchesShell(testCase: (name: String, config: String)) throws {
        guard FileManager.default.isExecutableFile(atPath: Self.reference.path) else { return }

        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "macarchy-ghostty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let configURL = root.appending(path: "config")
        let themeURL = root.appending(path: "theme.conf")
        try testCase.config.write(to: configURL, atomically: true, encoding: .utf8)
        try Self.themeConf.write(to: themeURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [Self.reference.path, configURL.path, themeURL.path, "midnight"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let shell = String(decoding: data, as: UTF8.self)
        let swift = GhosttyApplier.transform(
            config: testCase.config, themeConf: Self.themeConf, themeName: "midnight")

        #expect(swift == shell, "\(testCase.name) diverged from the shell")
    }
}
