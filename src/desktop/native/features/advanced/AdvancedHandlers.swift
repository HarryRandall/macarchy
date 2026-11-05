import AppKit
import Foundation
import Macarchy

extension BridgeRouter {
    /// `send` reaches the page that asked, for setup's progress.
    func registerAdvanced(
        model: AppModel, send: @escaping @MainActor (BridgeEvent) -> Void = { _ in }
    ) {
        registerSetup(model: model, send: send)
        registerCleanup(model: model)
        register("advanced.getState") { (_: Empty) in
            try await model.advancedState()
        }
        register("advanced.restartService") { (params: ServiceParams) in
            let result = await model.daemons.restart(params.daemon.daemon)
            guard result.ok else { throw BridgeFailure(.operationFailed, result.summary) }
            return Null()
        }
        register("advanced.stopService") { (params: ServiceParams) in
            let result = await model.daemons.stop(params.daemon.daemon)
            guard result.ok else { throw BridgeFailure(.operationFailed, result.summary) }
            return Null()
        }
        register("advanced.rebuild") { (params: RebuildParams) in
            try await Self.maintenance(model, name: "rebuild \(params.file.rawValue)") {
                let outcome = try model.advancedConfiguration.rebuild(params.file)
                let label: String
                switch outcome {
                case .written: label = "Rebuilt"
                case .unchanged: label = "Up to date"
                case .writtenOverDrift: label = "Edits backed up"
                case .failed(let message): throw ConfigurationError(message)
                }
                return RebuildResult(outcome: label)
            }
        }
        register("advanced.restoreSnapshot") { (params: SnapshotParams) in
            try await Self.maintenance(model, name: "restore backup") {
                try await model.advancedConfiguration.restoreSnapshot(id: params.id)
                await model.loadEverything()
                return Null()
            }
        }
        register("advanced.repairAddition") { (_: Empty) in
            let result = await model.advancedConfiguration.repairScriptingAddition()
            model.log.record(result)
            guard result.ok else { throw BridgeFailure(.operationFailed, result.summary) }
            return Null()
        }
        register("advanced.setLoginItem") { (params: LoginItemParams) in
            try await Self.maintenance(
                model, name: params.enabled ? "open at login" : "stop opening at login"
            ) {
                try model.loginItem.setEnabled(params.enabled)
                return Null()
            }
        }
        register("advanced.openLoginItems") { (_: Empty) in
            model.loginItem.openSettings()
            return Null()
        }
        registerRestore(model: model)
    }

    private func registerRestore(model: AppModel) {
        register("advanced.restoreOriginals") { (params: RestoreParams) in
            // Only tools Macarchy installed and still there are ever removed.
            let removable = model.setupSession.installer.removable()
            let removing = removable.filter { params.removeTools.contains($0.id) }
            guard Set(removing.map(\.id)) == Set(params.removeTools) else {
                throw BridgeFailure(
                    .invalidParams, "Only tools Macarchy installed can be removed")
            }
            return try await Self.maintenance(model, name: "restored original files") {
                let report = try await model.setupSession.restoreOriginals(removing: removing)
                for command in report.commands { model.log.record(command) }
                return SetupReport(report)
            }
        }
    }

    private func registerCleanup(model: AppModel) {
        register("advanced.getCleanupPlan") { (_: Empty) in
            CleanupPlanState(await OldConfiguration.plan())
        }
        // Like setup, a partial run resolves, so the page shows what changed
        // beside why it stopped.
        register("advanced.cleanUp") { (_: Empty) in
            let report = await OldConfiguration.apply(integrations: model.setupSession.integrations)
            for command in report.commands { model.log.record(command) }
            if let failure = report.failure {
                model.log.failure("clean up old configuration", failure)
            } else {
                model.log.note("clean up old configuration", "Completed")
            }
            await model.loadEverything()
            StateBroadcast.shared.settingsWritten()
            StateBroadcast.shared.advancedChanged()
            return CleanupReport(report)
        }
    }

    private func registerSetup(model: AppModel, send: @escaping @MainActor (BridgeEvent) -> Void) {
        register("setup.getPlan") { (params: SetupParams) in
            model.setupState(params.choices)
        }
        // A partial run resolves rather than rejects, so the page can show the
        // steps that already changed files next to the reason it stopped.
        // Missing tools are installed first, each step sent as it happens.
        register("setup.run") { (params: SetupParams) in
            let app = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
            // Without Homebrew the page has said the missing tools wait for it.
            let report = await model.setupSession.run(
                params.choices, app: app, install: ToolInstaller.homebrew != nil
            ) { step in
                // The main queue keeps Homebrew's lines in the order they came.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { send(.setupProgress(SetupProgress(step))) }
                }
            }
            for command in report.commands { model.log.record(command) }
            if let failure = report.failure {
                model.log.failure("set up Macarchy", failure)
            } else {
                model.log.note("set up Macarchy", "Completed")
                if let problem = model.loginItem.turnOnOnce() {
                    model.log.failure("open at login", problem)
                }
                SpaceSwitcherController.shared.askForPermission()
            }
            await model.loadEverything()
            StateBroadcast.shared.settingsWritten()
            StateBroadcast.shared.advancedChanged()
            return SetupReport(report)
        }
        // Homebrew's installer asks for the person's password, so it runs in
        // Terminal where they can answer; the page checks again afterwards.
        register("setup.installHomebrew") { (_: Empty) in
            do {
                let script = try ToolInstaller.homebrewInstaller()
                if let problem = model.openInTerminal(script) {
                    throw ConfigurationError(problem)
                }
                model.log.note("install Homebrew", "Opened the installer in Terminal")
                return Null()
            } catch {
                model.log.failure("install Homebrew", error.localizedDescription)
                throw BridgeFailure(.operationFailed, error.localizedDescription)
            }
        }
        register("setup.openAccessibility") { (_: Empty) in
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            {
                NSWorkspace.shared.open(url)
            }
            return Null()
        }
    }

    private static func maintenance<T>(
        _ model: AppModel, name: String, operation: () async throws -> T
    ) async throws -> T {
        do {
            let result = try await operation()
            model.log.note(name, "Completed")
            StateBroadcast.shared.settingsWritten()
            StateBroadcast.shared.advancedChanged()
            return result
        } catch {
            model.log.failure(name, error.localizedDescription)
            StateBroadcast.shared.advancedChanged()
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}

extension SetupReport {
    init(_ report: SetupSession.Report) {
        lines = report.lines
        failures = report.commands.filter { !$0.ok }.map(\.summary)
        failure = report.failure
    }
}

extension CleanupPlanState {
    init(_ plan: OldConfiguration.Plan) {
        sections = plan.sections.map { section in
            .init(
                title: section.title,
                lines: section.lines.map { .init(path: $0.path, detail: $0.detail) })
        }
        hasChanges = plan.refusal == nil && plan.hasChanges
        refusal = plan.refusal
    }
}

extension CleanupReport {
    init(_ report: OldConfiguration.Report) {
        lines = report.lines
        failures = report.commands.filter { !$0.ok }.map(\.summary)
        failure = report.failure
        archive = report.archive.map(Paths.display)
    }
}

extension AppModel {
    /// One line for each of `Setup.extras`, by id.
    static let extraDescriptions: [String: String] = [:]

    /// The plan for `choices`, with every tool and whether it was chosen
    /// last time, so the page starts from the earlier answers.
    func setupState(_ choices: Setup.Choices) -> SetupState {
        let plan = Setup.plan(choices)
        let chosen = Setup.chosenTools
        return SetupState(
            // Window management first, then what draws on top of it.
            tools: [Daemon.yabai, .skhd, .sketchybar, .borders].map {
                .init(
                    id: $0.rawValue, name: $0.displayName, description: $0.summary,
                    installed: Paths.isInstalled($0.executableName), chosen: chosen.contains($0),
                    ownConfig: Setup.ownConfig($0).map(Paths.display))
            },
            extras: Setup.extras.map {
                .init(
                    id: $0.id, name: $0.name, description: Self.extraDescriptions[$0.id] ?? "",
                    installed: $0.isInstalled)
            },
            homebrew: ToolInstaller.homebrew != nil,
            changes: plan.map {
                .init(path: Paths.display($0.path), action: $0.action.rawValue, detail: $0.detail)
            },
            canClose: !setupRequired,
            notices: LegacyLayout.note?.lines ?? [])
    }

    func advancedState() async throws -> AdvancedState {
        do {
            if FileManager.default.fileExists(atPath: settingsStore.url.path) {
                _ = try settingsStore.read()
            }
            await daemons.refresh()
            snapshots.refresh()
            themes.reload()
            let status = ScriptingAddition.status()
            let addition: String
            switch status {
            case .permitted: addition = "active"
            case .binaryMissing, .bundleMissing: addition = "missing"
            case .ruleMissing, .hashStale: addition = "repair"
            case .isolated: addition = "unavailable"
            }
            return AdvancedState(
                services: Daemon.allCases.map { daemon in
                    let state = ShellState.Service.State(daemons.states[daemon])
                    return .init(id: daemon.rawValue, state: state.rawValue)
                },
                snapshots: snapshots.snapshots.map {
                    .init(
                        id: $0.id, created: $0.created.timeIntervalSince1970 * 1000,
                        files: $0.files.count, reason: snapshots.reason(for: $0))
                },
                theme: themes.current ?? "None", installedThemes: themes.themes.count,
                addition: addition, additionExplanation: status.explanation,
                wakeHelpers: await advancedConfiguration.wakeHelpersRegistered(),
                backupsDirectory: Paths.display(Paths.backupsDirectory),
                loginItem: loginItem.state(),
                removableTools: setupSession.installer.removable().map {
                    .init(id: $0.id, name: $0.name)
                })
        } catch {
            log.failure("read advanced", error.localizedDescription)
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}
