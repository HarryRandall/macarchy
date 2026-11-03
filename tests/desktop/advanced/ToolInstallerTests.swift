import Foundation
import Testing

@testable import App
@testable import Macarchy

/// What an installer reported, gathered from the threads Homebrew's output
/// arrives on.
final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [ToolInstaller.Progress] = []
    private var stepsTaken: [SetupSession.Step] = []

    func record(_ progress: ToolInstaller.Progress) { lock.withLock { recorded.append(progress) } }
    func record(_ step: SetupSession.Step) {
        lock.withLock {
            stepsTaken.append(step)
            if case .homebrew(let progress) = step { recorded.append(progress) }
        }
    }
    var events: [ToolInstaller.Progress] { lock.withLock { recorded } }
    var steps: [SetupSession.Step] { lock.withLock { stepsTaken } }
}

extension Harness {
    /// A fake `brew` on the search path. `install` puts an executable for the
    /// formula's last part beside it, printing two lines as Homebrew does;
    /// `uninstall` removes it. A formula named in `failing` fails instead.
    /// Every call is logged in `brew.log` in the home.
    func installFakeHomebrew(failing: [String] = []) throws {
        let script = """
            #!/bin/sh
            bin="$(cd "$(dirname "$0")" && pwd)"
            printf '%s\\n' "brew $*" >> "$bin/../brew.log"
            name="${2##*/}"
            for failing in \(failing.joined(separator: " ")); do
              if [ "$failing" = "$name" ]; then
                echo "Error: No available formula with the name \\"$name\\"" >&2
                exit 1
              fi
            done
            case "$1" in
              install)
                echo "==> Fetching $name"
                echo "==> Pouring $name"
                printf '#!/bin/sh\\nexit 0\\n' > "$bin/$name"
                chmod +x "$bin/$name" ;;
              uninstall)
                rm -f "$bin/$name"
                echo "Uninstalling $name" ;;
            esac

            """
        let file = bin.appending(path: "brew")
        try Data(script.utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    var brewCalls: [String] {
        ((try? String(contentsOf: home.appending(path: "brew.log"), encoding: .utf8)) ?? "")
            .split(separator: "\n").map(String.init)
    }
}

extension WebInterfaceTests {
    /// Installing with Homebrew, through a fake `brew` on the search path.
    @MainActor
    @Suite("Tool installer")
    struct ToolInstallerTests {
        @Test("installs only what is missing, passing Homebrew's lines on, and records it")
        func installs() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                try harness.installFakeHomebrew()
                let installer = ToolInstaller()
                let log = ProgressLog()
                let report = await installer.install([Daemon.yabai.package, Daemon.skhd.package]) {
                    log.record($0)
                }
                #expect(report.changed == [Daemon.yabai.package])
                #expect(report.unchanged == [Daemon.skhd.package])
                #expect(report.failures.isEmpty)
                #expect(Paths.isInstalled("yabai"))
                #expect(harness.brewCalls == ["brew install asmvik/formulae/yabai"])
                let yabai = Daemon.yabai.package
                #expect(
                    log.events == [
                        .started(yabai), .output(yabai, "==> Fetching yabai"),
                        .output(yabai, "==> Pouring yabai"), .finished(yabai)
                    ])
                // skhd was there before, so it is never offered for removal.
                #expect(try installer.installed() == [yabai])
                #expect(installer.removable() == [yabai])
            }
        }

        @Test("a failed install is reported with Homebrew's words and the rest still install")
        func failure() async throws {
            try await withHarness(tools: []) { harness in
                try harness.installFakeHomebrew(failing: ["sketchybar"])
                let installer = ToolInstaller()
                let log = ProgressLog()
                let report = await installer.install([
                    Daemon.sketchybar.package, Daemon.borders.package
                ]) { log.record($0) }
                #expect(report.changed == [Daemon.borders.package])
                let failure = try #require(report.failures.first)
                #expect(failure.package == Daemon.sketchybar.package)
                #expect(failure.reason.contains("No available formula"))
                #expect(
                    log.events.contains(.failed(Daemon.sketchybar.package, failure.reason)))
                #expect(try installer.installed() == [Daemon.borders.package])
            }
        }

        @Test("Homebrew that finishes without the tool is a failure, not an install")
        func silentFailure() async throws {
            try await withHarness(tools: ["brew"]) { _ in
                let installer = ToolInstaller(run: { _, _, line in
                    line("Already up to date")
                    return CommandResult(command: "brew install", status: 0)
                })
                let report = await installer.install([.neovim])
                #expect(report.changed.isEmpty)
                #expect(report.failures.first?.reason.contains("nvim is still missing") == true)
                let recorded = try installer.installed()
                #expect(recorded.isEmpty)
            }
        }

        @Test("without Homebrew nothing runs and each tool says why")
        func noHomebrew() async throws {
            try await withHarness(tools: []) { _ in
                let installer = ToolInstaller(run: { _, _, _ in
                    Issue.record("Homebrew is missing, so nothing may run")
                    return CommandResult(command: "brew", status: 1)
                })
                #expect(ToolInstaller.homebrew == nil)
                let report = await installer.install([Daemon.yabai.package])
                #expect(report.failures.map(\.reason) == [ToolInstaller.homebrewMissing])
            }
        }

        @Test("removing refuses anything Macarchy did not install")
        func removes() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                try harness.installFakeHomebrew()
                let installer = ToolInstaller()
                _ = await installer.install([Daemon.yabai.package])
                let report = await installer.uninstall([
                    Daemon.skhd.package, Daemon.yabai.package
                ])
                #expect(report.changed == [Daemon.yabai.package])
                #expect(report.failures.map(\.package) == [Daemon.skhd.package])
                #expect(Paths.isInstalled("skhd"))
                #expect(!Paths.isInstalled("yabai"))
                #expect(
                    !harness.brewCalls.contains { $0.contains("uninstall asmvik/formulae/skhd") })
                #expect(try installer.installed().isEmpty)
            }
        }

        @Test("Homebrew's installer is written for Terminal and never run here")
        func homebrewInstaller() throws {
            let script = try ToolInstaller.homebrewInstaller()
            let text = try String(contentsOf: script, encoding: .utf8)
            #expect(text.hasPrefix("#!/bin/bash\n"))
            #expect(
                text.contains("https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"))
            #expect(FileManager.default.isExecutableFile(atPath: script.path))
            #expect(script.pathExtension == "command")
        }

        @Test("the cask and formula packages name what Homebrew is given")
        func packages() {
            #expect(ToolInstaller.Package.ghostty.command == "brew install --cask ghostty")
            #expect(ToolInstaller.Package.neovim.command == "brew install neovim")
            #expect(
                Daemon.sketchybar.installCommand == "brew install FelixKratz/formulae/sketchybar")
        }
    }
}
