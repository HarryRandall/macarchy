import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Setup configures only the tools a person chose, each from their own
    /// config or Macarchy's defaults, installing missing ones first.
    @MainActor
    @Suite("Setup with chosen tools")
    struct ToolChoiceSetupTests {
        private static let fm = FileManager.default

        @Test("tools left out get no startup file, agent or service, and the choice is saved")
        func leftAlone() async throws {
            try await withHarness(tools: ["yabai", "skhd", "sketchybar", "borders"]) { harness in
                try await withSetupResources(harness) {
                    try Self.fm.removeItem(at: harness.store.url)
                    let choices = Setup.Choices(tools: [.yabai, .borders])
                    let plan = Setup.plan(choices).map(\.path)
                    #expect(plan.contains(StartupConfiguration.yabairc.url))
                    #expect(!plan.contains(Setup.skhdrc))
                    #expect(!plan.contains(StartupConfiguration.sketchybarrc.url))
                    #expect(!plan.contains(DaemonAgents.plist(.skhd)))
                    let report = await harness.model.setupSession.run(choices, app: nil)
                    #expect(report.failure == nil)
                    for file in [
                        StartupConfiguration.yabairc.url, StartupConfiguration.bordersrc.url
                    ] {
                        #expect(Self.fm.fileExists(atPath: file.path))
                    }
                    for file in [
                        Setup.skhdrc, StartupConfiguration.sketchybarrc.url,
                        DaemonAgents.plist(.skhd), DaemonAgents.plist(.sketchybar)
                    ] {
                        #expect(!Self.fm.fileExists(atPath: file.path))
                    }
                    #expect(Self.fm.fileExists(atPath: DaemonAgents.plist(.yabai).path))
                    #expect(try harness.store.read().tools == ["yabai", "borders"])
                    #expect(Setup.chosenTools == [.yabai, .borders])
                    #expect(Daemon.yabai.isManaged && !Daemon.skhd.isManaged)
                    // No bar was set up, so the widget host has nothing to send.
                    #expect(try harness.store.read().barConfiguration == nil)
                    let started = await harness.desktop.calls(to: "launchctl")
                        .filter { $0.first == "bootstrap" }.compactMap(\.last)
                    #expect(started.contains(DaemonAgents.plist(.yabai).path))
                    #expect(!started.contains(DaemonAgents.plist(.skhd).path))
                    let checks = Doctor.dependencyChecks()
                    #expect(
                        checks.first { $0.title == "skhd" }?.detail
                            == "Left out of setup, so Macarchy leaves it alone")
                }
            }
        }

        @Test("each tool keeps its own config or starts from defaults, as chosen")
        func perTool() async throws {
            try await withHarness(tools: ["yabai", "skhd"]) { harness in
                try await withSetupResources(harness) {
                    try Self.fm.removeItem(at: harness.store.url)
                    try harness.write(
                        "yabai -m config window_gap 17\n", to: ".config/yabai/yabairc")
                    try harness.write("cmd - h : echo mine\n", to: ".config/skhd/skhdrc")
                    #expect(Setup.ownConfig(.yabai) != nil)
                    #expect(Setup.ownConfig(.skhd) != nil)
                    #expect(Setup.ownConfig(.sketchybar) == nil)
                    let choices = Setup.Choices(
                        tools: [.yabai, .skhd], existing: [.yabai: .keep, .skhd: .replace])
                    let skhd = Setup.plan(choices).first { $0.path == Setup.skhdrc }
                    #expect(skhd?.detail == "Installs Macarchy's default shortcuts")
                    let report = await harness.model.setupSession.run(
                        choices, app: nil, applyToDesktop: false)
                    #expect(report.failure == nil)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    let shortcuts = try String(contentsOf: Setup.skhdrc, encoding: .utf8)
                    #expect(!shortcuts.contains("echo mine"))
                    #expect(shortcuts.contains("\nctrl - left : "))
                    // Once Macarchy's copies exist there is nothing left to choose.
                    #expect(Setup.ownConfig(.yabai) == nil)
                    #expect(Setup.ownConfig(.skhd) == nil)
                }
            }
        }

        @Test("missing chosen tools are installed first, then configured and started")
        func installsThenConfigures() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try Self.fm.removeItem(at: harness.store.url)
                    try harness.installFakeHomebrew(failing: ["borders"])
                    let log = ProgressLog()
                    let choices = Setup.Choices(tools: [.yabai, .sketchybar, .borders])
                    let report = await harness.model.setupSession.run(
                        choices, app: nil, install: true
                    ) { log.record($0) }
                    #expect(report.failure == nil)
                    #expect(report.lines.contains("Installed SketchyBar with Homebrew"))
                    #expect(report.lines.contains { $0.hasPrefix("borders was not installed") })
                    #expect(
                        report.commands.contains {
                            !$0.ok && $0.stderr.hasPrefix("borders was not installed")
                        })
                    #expect(log.steps.last == .configuring)
                    #expect(harness.brewCalls.allSatisfy { !$0.contains("yabai") })
                    #expect(Self.fm.fileExists(atPath: DaemonAgents.plist(.sketchybar).path))
                    // borders is still configured, so it starts once installed.
                    #expect(Self.fm.fileExists(atPath: StartupConfiguration.bordersrc.url.path))
                    #expect(!Self.fm.fileExists(atPath: DaemonAgents.plist(.borders).path))
                    #expect(
                        harness.model.setupSession.installer.removable() == [
                            Daemon.sketchybar.package
                        ])
                }
            }
        }

        @Test("restoring removes only the tools asked for, and hands back the rest")
        func restoreRemovesTools() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try harness.installFakeHomebrew()
                    let session = harness.model.setupSession
                    _ = await session.run(
                        Setup.Choices(tools: [.yabai, .skhd]), app: nil, applyToDesktop: false,
                        install: true)
                    #expect(Paths.isInstalled("skhd"))
                    let report = try await session.restoreOriginals(
                        removing: session.installer.removable())
                    #expect(report.lines.contains("Removed skhd with Homebrew"))
                    #expect(!Paths.isInstalled("skhd"))
                    #expect(Paths.isInstalled("yabai"))
                    #expect(harness.brewCalls.last == "brew uninstall asmvik/formulae/skhd")
                    #expect(session.installer.removable().isEmpty)
                }
            }
        }

        @Test("the bridge refuses to remove a tool Macarchy did not install")
        func bridgeRefusesRemoval() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                let router = BridgeRouter()
                router.registerAdvanced(model: harness.model)
                let reply = await router.handle([
                    "method": "advanced.restoreOriginals", "params": ["removeTools": ["yabai"]]
                ])
                #expect(reply.contains("invalid_params"))
                #expect(Paths.isInstalled("yabai"))
            }
        }
    }
}
