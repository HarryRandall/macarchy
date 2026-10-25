import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Uses the parent's isolated environment without creating a web view.
    @MainActor
    @Suite("Start launchers")
    struct StartLauncherTests {
        /// yabai and SketchyBar run the file they start with as `sh -c <path>`,
        /// unquoted. Started from `config/` itself, the space in Application
        /// Support split the path and the file never ran.
        @Test("yabai and SketchyBar start from launchers that sh runs whole")
        func launchersSurviveShell() async throws {
            try await withHarness(tools: ["yabai", "sketchybar"]) { harness in
                let environment = ["HOME": harness.home.path, "PATH": "/usr/bin:/bin"]
                for launcher in StartLauncher.all {
                    let marker = harness.home.appending(path: "ran-\(launcher.daemon.rawValue)")
                    try FileManager.default.createDirectory(
                        at: launcher.target.deletingLastPathComponent(),
                        withIntermediateDirectories: true)
                    try "#!/bin/bash\ntouch '\(marker.path)'\n".write(
                        to: launcher.target, atomically: true, encoding: .utf8)
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o755], ofItemAtPath: launcher.target.path)
                    _ = try launcher.place(backups: Backups())
                    try install(launcher.daemon)

                    let start = try #require(Doctor.startFile(launcher.daemon))
                    #expect(start == launcher.url)
                    #expect(start.path.rangeOfCharacter(from: .whitespaces) == nil)
                    #expect(Doctor.startFileProblem(launcher.daemon) == nil)
                    let split = await CommandRunner.run(
                        "/bin/sh", ["-c", launcher.target.path], environment: environment)
                    #expect(!split.ok && split.stderr.contains("No such file"))
                    let started = await CommandRunner.run(
                        "/bin/sh", ["-c", start.path], environment: environment)
                    #expect(started.ok, "\(started.stderr)")
                    #expect(FileManager.default.fileExists(atPath: marker.path))
                }
            }
        }

        /// The agents a machine has until setup runs again name the file in
        /// Application Support, and a launcher can go missing.
        @Test("Doctor reports an agent whose start file cannot run")
        func reportsUnrunnableStartFile() async throws {
            try await withHarness(tools: ["yabai"]) { _ in
                let old: [String: Any] = [
                    "Label": DaemonAgents.label(.yabai),
                    "ProgramArguments": [Paths.yabai, "-c", StartupConfiguration.yabairc.url.path]
                ]
                try FileManager.default.createDirectory(
                    at: DaemonAgents.plist(.yabai).deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try PropertyListSerialization.data(fromPropertyList: old, format: .xml, options: 0)
                    .write(to: DaemonAgents.plist(.yabai))
                let split = try #require(Doctor.startFileProblem(.yabai))
                #expect(split.contains("splitting the path at the space"))

                try install(.yabai)
                let missing = try #require(Doctor.startFileProblem(.yabai))
                #expect(missing.contains("macarchy-yabairc, which is missing"))

                _ = try StartLauncher.yabai.place(backups: Backups())
                #expect(Doctor.startFileProblem(.yabai) == nil)
            }
        }
    }
}

private func install(_ daemon: Daemon) throws {
    var report: [String] = []
    try DaemonAgents.install(daemon, backups: Backups(), report: &report)
}
