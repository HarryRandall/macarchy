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
                    let first = await harness.model.setupSession.run(existing: .keep, app: nil)
                    #expect(first.failure == nil)
                    let yabairc = Paths.display(StartupConfiguration.yabairc.url)
                    #expect(first.lines.contains("Wrote \(yabairc)"))
                    #expect(first.lines.contains("Wrote \(Paths.display(harness.store.url))"))
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            .contains("echo mine"))
                    let repeated = await harness.model.setupSession.run(existing: .keep, app: nil)
                    #expect(repeated.failure == nil)
                    #expect(
                        !repeated.lines.contains {
                            $0.hasPrefix("Wrote") || $0.hasPrefix("Backed up")
                        })
                    _ = try await harness.model.setupSession.restoreOriginals()
                    // Setup only read the person's yabairc; it never changed it.
                    #expect(
                        try String(
                            contentsOf: harness.home.appending(path: ".config/yabai/yabairc"),
                            encoding: .utf8) == original)
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
                    let report = await harness.model.setupSession.run(
                        existing: .replace, app: nil)
                    #expect(report.failure == nil)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] != "29")
                    #expect(report.commands.contains { !$0.ok })
                    #expect(report.lines.contains { $0.contains("Some changes applied") })
                    #expect(report.commands.contains { $0.command.hasPrefix("record theme") })
                    #expect(await bootstrapped(.yabai, harness))
                }
            }
        }

        @Test("without applying to the desktop only the file steps run, with a full run's lines")
        func filesOnly() async throws {
            let themes = ThemeCalls()
            var filesOnly: [String] = []
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try harness.write(
                        "yabai -m config window_gap 17\n", to: ".config/yabai/yabairc")
                    let session = SetupSession(
                        integrations: harness.model.backend,
                        applyTheme: { await themes.record($0) })
                    let report = await session.run(
                        existing: .keep, app: nil, applyToDesktop: false)
                    #expect(report.failure == nil)
                    #expect(report.commands.isEmpty)
                    #expect(await harness.desktop.calls.isEmpty)
                    #expect(await themes.names.isEmpty)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    filesOnly = report.lines
                }
            }
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try harness.write(
                        "yabai -m config window_gap 17\n", to: ".config/yabai/yabairc")
                    let session = SetupSession(
                        integrations: harness.model.backend,
                        applyTheme: { await themes.record($0) })
                    let full = await session.run(existing: .keep, app: nil)
                    #expect(full.failure == nil)
                    #expect(await bootstrapped(.yabai, harness))
                    #expect(await themes.names.count == 1)
                    #expect(!filesOnly.isEmpty)
                    #expect(Array(full.lines.prefix(filesOnly.count)) == filesOnly)
                    #expect(full.lines.count == filesOnly.count + full.commands.count)
                }
            }
        }

        @Test("a step failing after earlier steps returns their lines with the failure")
        func partialFailureKeepsReport() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    try harness.write(
                        "yabai -m config window_gap 17\n", to: ".config/yabai/yabairc")
                    // A folder where the bar's startup file goes makes the third
                    // file step fail after yabai and the shortcuts are written.
                    try FileManager.default.createDirectory(
                        at: StartupConfiguration.sketchybarrc.url,
                        withIntermediateDirectories: true)
                    let report = await harness.model.setupSession.run(existing: .keep, app: nil)
                    #expect(report.lines.contains { $0.hasPrefix("Moved") })
                    #expect(report.lines.contains("Installed default shortcuts"))
                    let yabairc = Paths.display(StartupConfiguration.yabairc.url)
                    #expect(report.lines.contains("Wrote \(yabairc)"))
                    #expect(report.lines.contains("Wrote \(Paths.display(harness.store.url))"))
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    let failure = try #require(report.failure)
                    #expect(failure.hasPrefix("Setup did not finish"))
                    #expect(report.commands.isEmpty)
                    #expect(await harness.desktop.calls.isEmpty)
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            .contains("# Generated by Macarchy."))
                }
            }
        }

        @Test("a failed theme copy reports the themes before it and leaves no partial folder")
        func partialThemeInstall() async throws {
            try await withHarness(themes: [], tools: []) { harness in
                try await withSetupResources(harness) {
                    let fm = FileManager.default
                    let bundled = try #require(Paths.resources).appending(path: "themes")
                    // The same listing setup walks, so the broken theme is the last one copied.
                    let order = try fm.contentsOfDirectory(
                        at: bundled, includingPropertiesForKeys: nil
                    )
                    .filter { Theme.load(from: $0) != nil }
                    let broken = try #require(order.last)
                    let locked = broken.appending(path: "locked")
                    try "unreadable".write(to: locked, atomically: true, encoding: .utf8)
                    try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)
                    defer {
                        try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path)
                    }

                    let report = await harness.model.setupSession.run(existing: .keep, app: nil)
                    #expect(report.failure?.hasPrefix("Setup did not finish") == true)
                    let names = order.dropLast().map(\.lastPathComponent)
                    #expect(report.lines == ["Installed themes: \(names.joined(separator: ", "))"])
                    let installed = try fm.contentsOfDirectory(atPath: Paths.themesDirectory.path)
                    #expect(Set(installed) == Set(names))
                }
            }
        }

        @Test("unreadable settings after the file steps say only the theme was left out")
        func unreadableSettingsAfterSetup() async throws {
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    let settings = harness.store.url
                    // Starting the services is the last step before the theme is read.
                    await harness.desktop.answer("launchctl") { arguments in
                        guard arguments.first == "bootstrap" else { return nil }
                        try? "{".write(to: settings, atomically: true, encoding: .utf8)
                        return .success()
                    }
                    let report = await harness.model.setupSession.run(existing: .keep, app: nil)
                    let failure = try #require(report.failure)
                    #expect(failure.hasPrefix("Setup finished, but the theme was not applied"))
                    #expect(!report.lines.isEmpty)
                    #expect(!report.commands.contains { $0.command.hasPrefix("record theme") })
                }
            }
        }

        @Test("a partial setup resolves over the bridge with its lines and an explicit failure")
        func partialFailureOverBridge() async throws {
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.createDirectory(
                        at: StartupConfiguration.sketchybarrc.url,
                        withIntermediateDirectories: true)
                    let router = BridgeRouter()
                    router.registerAdvanced(model: harness.model)
                    let reply = await router.handle(
                        ["method": "setup.run", "params": ["existing": "keep"]])
                    let parsed = try #require(
                        JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any])
                    #expect(parsed["ok"] as? Bool == true)
                    let value = try #require(parsed["value"] as? [String: Any])
                    let lines = try #require(value["lines"] as? [String])
                    #expect(lines.contains("Installed default shortcuts"))
                    let failure = try #require(value["failure"] as? String)
                    #expect(failure.hasPrefix("Setup did not finish"))
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

/// Whether starting the services loaded Macarchy's agent for `daemon`.
@MainActor
private func bootstrapped(_ daemon: Daemon, _ harness: Harness) async -> Bool {
    await harness.desktop.calls(to: "launchctl").contains {
        $0.first == "bootstrap" && $0.last == DaemonAgents.plist(daemon).path
    }
}

/// The themes a setup session asked to apply, in place of the desktop.
private actor ThemeCalls {
    private(set) var names: [String] = []

    func record(_ name: String) -> CommandResult {
        names.append(name)
        return CommandResult(command: "record theme \(name)", status: 0, stdout: "Theme recorded")
    }
}
