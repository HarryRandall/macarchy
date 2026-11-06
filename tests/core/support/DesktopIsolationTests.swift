import Foundation
import Testing

@testable import Macarchy

/// The rule is tested with its inputs passed in: the web view suites change
/// `MACARCHY_HOME` and `MACARCHY_SEARCH_PATH` for the whole test process.
@Suite("Desktop isolation")
struct DesktopIsolationTests {
    let roots = ["/tmp/home", "/tmp/home/fake-bin"]

    func refusal(_ executable: String, _ arguments: [String] = []) -> String? {
        DesktopIsolation.refusal(executable, arguments, allowedRoots: roots)
    }

    @Test("session tools only run as fakes under the home or search path")
    func sessionTools() {
        let tools = DesktopIsolation.sessionTools.map { "/usr/bin/" + $0 } + ["/bin/launchctl"]
        for tool in tools {
            #expect(refusal(tool, ["anything"]) != nil, "\(tool)")
        }
        #expect(refusal("/tmp/home/fake-bin/launchctl", ["print", "gui/501/x"]) == nil)
        let bin = "/tmp/home/Library/Application Support/Macarchy/bin"
        #expect(refusal(bin + "/defaults", ["read", "-g", "x"]) == nil)
    }

    @Test("only fake daemons run")
    func fakeDaemons() {
        #expect(refusal("/tmp/home/fake-bin/yabai", ["-m", "config"]) == nil)
        #expect(refusal("/tmp/home/Library/Application Support/Macarchy/bin/borders") == nil)
        #expect(refusal("/opt/homebrew/bin/yabai", ["-m", "config"]) != nil)
        #expect(refusal("/opt/homebrew/bin/brew", ["services", "start", "sketchybar"]) != nil)
        // A root that is only a prefix of another directory does not count,
        // and neither does an empty root or the file system root.
        #expect(refusal("/tmp/home-other/sketchybar") != nil)
        #expect(
            DesktopIsolation.refusal("/opt/homebrew/bin/yabai", [], allowedRoots: ["", "/"]) != nil)
        // `..` cannot climb out of an allowed folder.
        #expect(refusal("/tmp/home/fake-bin/../../../opt/homebrew/bin/yabai") != nil)
    }

    @Test("other programs run")
    func otherPrograms() {
        #expect(refusal("/bin/bash", ["-c", "printf ready"]) == nil)
        #expect(refusal("/bin/sleep", ["1"]) == nil)
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

    @Test("the person's own scripts are only ever checked, never run")
    func personalScripts() {
        let mine = [
            "/tmp/home/Library/Application Support/Macarchy/scripts", "/tmp/home/.config/yabai"
        ]
        func refusal(_ executable: String, _ arguments: [String] = []) -> String? {
            DesktopIsolation.refusal(
                executable, arguments, allowedRoots: ["/tmp/home"], personalScripts: mine)
        }
        let script = "/tmp/home/.config/yabai/switch_space_native.sh"
        #expect(refusal(script, ["3"]) != nil)
        #expect(refusal("/bin/bash", [script, "3"]) != nil)
        #expect(refusal("/bin/sh", ["-e", mine[0] + "/launch.sh"]) != nil)
        #expect(refusal("/bin/bash", ["-n", script]) == nil)
        #expect(refusal("/bin/zsh", ["-n", script]) == nil)
        #expect(refusal("/bin/bash", ["/tmp/home/other.sh"]) == nil)
    }
}
