import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Uses the parent's isolated environment without creating a web view.
    @MainActor
    @Suite("Setup core operations")
    struct SetupOperationTests {
        @Test("keep, repeat and restore share one implementation with the bridge")
        func keepRepeatRestore() async throws {
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    let original = "yabai -m config window_gap 17\necho mine\n"
                    try harness.write(original, to: ".config/yabai/yabairc")
                    let before = harness.settingsData
                    let plan = Setup.plan(existing: .keep)
                    #expect(plan.contains { $0.action == .adopt })
                    #expect(harness.settingsData == before)
                    #expect(await harness.desktop.calls.isEmpty)
                    _ = try await harness.model.setupSession.run(existing: .keep, app: nil)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            .contains("echo mine"))
                    _ = try await harness.model.setupSession.run(existing: .keep, app: nil)
                    _ = try await harness.model.setupSession.restoreOriginals()
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            == original)
                }
            }
        }

        @Test(
            "start fresh replaces existing values, reports service failures and records theme application"
        )
        func replaceAndPartialFailure() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try harness.write(
                        "yabai -m config window_gap 29\n", to: ".config/yabai/yabairc")
                    let report = try await harness.model.setupSession.run(
                        existing: .replace, app: nil)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] != "29")
                    #expect(report.commands.contains { !$0.ok })
                    #expect(report.lines.contains { $0.contains("Some changes applied") })
                    #expect(report.commands.contains { $0.command.hasPrefix("record theme") })
                    #expect(await harness.desktop.calls(to: "yabai").contains(["--start-service"]))
                }
            }
        }

        @Test("typed bridge parameters reject arbitrary daemon and file names without writes")
        func invalidBridgeParameters() async throws {
            try await withHarness { harness in
                let router = BridgeRouter()
                router.registerAdvanced(model: harness.model)
                let before = harness.settingsData
                for body in [
                    ["method": "advanced.restartService", "params": ["daemon": "anything"]],
                    ["method": "advanced.rebuild", "params": ["file": "../../settings.json"]],
                    ["method": "setup.run", "params": ["existing": "anything"]]
                ] {
                    let reply = await router.handle(body)
                    #expect(reply.contains("invalid_params"))
                }
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.calls.isEmpty)
            }
        }

        @Test(
            "rebuilding preserves drift as a snapshot and a missing backup leaves settings unchanged"
        )
        func driftAndMissingBackup() async throws {
            try await withHarness(tools: []) { harness in
                let configuration = harness.model.advancedConfiguration
                _ = try configuration.rebuild(.yabairc)
                let generated = try String(
                    contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                try (generated + "echo edited\n").write(
                    to: StartupConfiguration.yabairc.url, atomically: true, encoding: .utf8)
                let outcome = try configuration.rebuild(.yabairc)
                if case .writtenOverDrift = outcome {
                } else {
                    Issue.record("Expected drift to be backed up")
                }
                #expect(!SnapshotStore().list().isEmpty)
                let before = harness.settingsData
                await #expect(throws: ConfigurationError.self) {
                    try await configuration.restoreSnapshot(id: "missing")
                }
                #expect(harness.settingsData == before)
            }
        }
    }
}
