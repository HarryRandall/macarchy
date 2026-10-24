import Foundation
import Testing

@testable import Macarchy

/// The rule is tested with its inputs passed in: the web view suites change
/// `MACARCHY_HOME` and `MACARCHY_SEARCH_PATH` for the whole test process.
@Suite("Desktop isolation")
struct DesktopIsolationTests {
    let roots = ["/tmp/home", "/tmp/home/fake-bin"]
    let scripts = ["/repo/resources/sketchybar"]

    func refusal(_ executable: String, _ arguments: [String] = []) -> String? {
        DesktopIsolation.refusal(
            executable, arguments, allowedRoots: roots, bundledScripts: scripts)
    }

    @Test("session tools only run as fakes under the home or search path")
    func sessionTools() {
        let tools = DesktopIsolation.sessionTools.map { "/usr/bin/" + $0 } + ["/bin/launchctl"]
        for tool in tools {
            #expect(refusal(tool, ["anything"]) != nil, "\(tool)")
        }
        #expect(refusal("/tmp/home/fake-bin/launchctl", ["print", "gui/501/x"]) == nil)
        #expect(refusal("/tmp/home/.config/macarchy/bin/defaults", ["read", "-g", "x"]) == nil)
    }

    @Test("only fake daemons run")
    func fakeDaemons() {
        #expect(refusal("/tmp/home/fake-bin/yabai", ["-m", "config"]) == nil)
        #expect(refusal("/tmp/home/.config/macarchy/bin/borders") == nil)
        #expect(refusal("/opt/homebrew/bin/yabai", ["-m", "config"]) != nil)
        #expect(refusal("/opt/homebrew/bin/brew", ["services", "start", "sketchybar"]) != nil)
        // A root that is only a prefix of another directory does not count,
        // and neither does an empty root or the file system root.
        #expect(refusal("/tmp/home-other/sketchybar") != nil)
        #expect(
            DesktopIsolation.refusal(
                "/opt/homebrew/bin/yabai", [], allowedRoots: ["", "/"], bundledScripts: [])
                != nil)
        // `..` cannot climb out of an allowed folder.
        #expect(refusal("/tmp/home/fake-bin/../../../opt/homebrew/bin/yabai") != nil)
    }

    @Test("bundled bar scripts are refused but may be syntax checked")
    func bundledBarScripts() {
        #expect(refusal(scripts[0] + "/recolor.sh") != nil)
        #expect(refusal("/bin/bash", [scripts[0] + "/bar.sh"]) != nil)
        #expect(refusal("/bin/bash", ["-n", scripts[0] + "/bar.sh"]) == nil)
        #expect(refusal("/bin/bash", ["-c", "printf ready"]) == nil)
        #expect(refusal("/bin/sleep", ["1"]) == nil)
    }

    @Test("bar scripts reached through the app link are refused")
    func barScriptsThroughTheAppLink() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "macarchy-isolation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appending(path: "Installed/Macarchy.app")
        let bar = bundle.appending(path: "Contents/Resources/sketchybar")
        try FileManager.default.createDirectory(at: bar, withIntermediateDirectories: true)
        try "#!/bin/bash\n".write(
            to: bar.appending(path: "bar.sh"), atomically: true, encoding: .utf8)
        let appLink = root.appending(path: "home/.config/macarchy/Macarchy.app")
        try FileManager.default.createDirectory(
            at: appLink.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: appLink, withDestinationURL: bundle)
        let linked = appLink.appending(path: "Contents/Resources/sketchybar/bar.sh").path

        // Resources resolved to the bundle itself, as `Paths.resources` does
        // for the CLI, and resources from the repository with the link
        // pointing elsewhere.
        let resolved = DesktopIsolation.bundledScriptRoots(
            resources: bundle.appending(path: "Contents/Resources"), appLink: appLink)
        let repository = DesktopIsolation.bundledScriptRoots(
            resources: URL(fileURLWithPath: "/repo/resources"), appLink: appLink)
        for scripts in [resolved, repository] {
            func refusal(_ executable: String, _ arguments: [String] = []) -> String? {
                DesktopIsolation.refusal(
                    executable, arguments, allowedRoots: roots, bundledScripts: scripts)
            }
            #expect(refusal("/bin/bash", [linked]) != nil)
            #expect(refusal(linked) != nil)
            #expect(refusal("/bin/bash", [bar.appending(path: "bar.sh").path]) != nil)
            #expect(refusal("/bin/bash", ["-n", linked]) == nil)
        }
    }

    /// `MACARCHY_HOME` set to the account's own home relocates nothing, so
    /// the run behaves as an ordinary one rather than skip every daemon.
    @Test("the real home is not isolated")
    func realHome() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "macarchy-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let real = root.appending(path: "Users/person")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let alias = root.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let homes = [real.path]
        func isolated(_ home: String?) -> Bool {
            Paths.isolated(in: home.map { ["MACARCHY_HOME": $0] } ?? [:], homes: homes)
        }

        #expect(!isolated(nil))
        #expect(!isolated(real.path))
        #expect(!isolated(real.path + "/"))
        #expect(!isolated(real.path + "/../person"))
        #expect(!isolated(alias.path))
        #expect(isolated(root.appending(path: "temp-home").path))
        #expect(isolated(real.appending(path: "nested").path))
        #expect(!Paths.isolated(in: ["MACARCHY_HOME": NSHomeDirectory()]))
        // A search path still isolates, whatever the home.
        #expect(
            Paths.isolated(
                in: ["MACARCHY_HOME": real.path, "MACARCHY_SEARCH_PATH": ""], homes: homes))
    }

    /// The real home finds the real daemons; a relocated one without a
    /// search path finds none, rather than the Homebrew copies.
    @Test("an isolated home without a search path finds no daemons")
    func isolatedHomeFindsNoDaemons() throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "macarchy-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let environment = ["MACARCHY_HOME": home.path, "PATH": "/bin:/usr/bin"]
        #expect(Paths.searchDirectories(in: environment).isEmpty)
        #expect(Paths.executable("sh", in: environment).hasPrefix(home.path + "/"))
        #expect(Paths.searchDirectories(in: ["MACARCHY_HOME": NSHomeDirectory()]).count == 2)
    }

    /// The test process itself counts as isolated, so a test that forgets
    /// `MACARCHY_HOME` still cannot reach launchd or the appearance setting.
    @MainActor @Test("tests never reach the session")
    func testsNeverReachTheSession() async throws {
        #expect(DesktopIsolation.isTestProcess)
        guard DesktopIsolation.isActive else { return }
        let result = await CommandRunner.run(
            "/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])
        #expect(result.ok)
        #expect(!result.skipped.isEmpty)
        #expect(try Wallpaper.set(URL(fileURLWithPath: "/System")) == .skipped)
    }
}
