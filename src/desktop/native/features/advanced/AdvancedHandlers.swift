import AppKit
import Foundation
import Macarchy

extension BridgeRouter {
    func registerAdvanced(model: AppModel) {
        registerSetup(model: model)
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
        register("advanced.restoreOriginals") { (_: Empty) in
            try await Self.maintenance(model, name: "restored original files") {
                let report = try await model.setupSession.restoreOriginals()
                for command in report.commands { model.log.record(command) }
                return SetupReport(report)
            }
        }
    }

    private func registerSetup(model: AppModel) {
        register("setup.getPlan") { (params: SetupParams) in
            model.setupState(existing: params.existing)
        }
        // A partial run resolves rather than rejects, so the page can show the
        // steps that already changed files next to the reason it stopped.
        register("setup.run") { (params: SetupParams) in
            let app = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil
            let report = await model.setupSession.run(
                existing: params.existing == .keep ? .keep : .replace, app: app)
            for command in report.commands { model.log.record(command) }
            if let failure = report.failure {
                model.log.failure("set up Macarchy", failure)
            } else {
                model.log.note("set up Macarchy", "Completed")
            }
            await model.loadEverything()
            StateBroadcast.shared.settingsWritten()
            StateBroadcast.shared.advancedChanged()
            return SetupReport(report)
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

extension AppModel {
    func setupState(existing: SetupParams.Existing) -> SetupState {
        let plan = Setup.plan(existing: existing == .keep ? .keep : .replace)
        return SetupState(
            tools: Daemon.allCases.map {
                .init(
                    id: $0.rawValue, name: $0.displayName, role: $0.role,
                    installed: Paths.isInstalled($0.executableName),
                    installCommand: $0.installCommand)
            },
            changes: plan.map {
                .init(path: Paths.display($0.path), action: $0.action.rawValue, detail: $0.detail)
            },
            hasExisting: plan.contains { $0.action == .adopt || $0.action == .replace },
            canClose: FileManager.default.fileExists(atPath: settingsStore.url.path))
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
                backupsDirectory: Paths.display(Paths.backupsDirectory))
        } catch {
            log.failure("read advanced", error.localizedDescription)
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}
