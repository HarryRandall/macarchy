import AppKit
import Macarchy

extension BridgeRouter {
    func registerShortcuts(model: AppModel) {
        register("shortcuts.getState") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return try await model.readShortcuts()
        }
        register("shortcuts.validate") { [weak model] (params: ShortcutValidateParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            do {
                let chord = try params.chord.validated()
                let conflict = try SkhdShortcuts(integrations: model.backend).validate(
                    chord, excluding: params.id)
                return ShortcutValidation(
                    spec: chord.keySpec, caps: chord.caps, conflicts: conflict.map { [$0] } ?? [])
            } catch {
                model.log.failure("validate shortcut", error.localizedDescription)
                throw BridgeFailure(.invalidParams, error.localizedDescription)
            }
        }
        register("shortcuts.rebind") { [weak model] (params: ShortcutEditParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return try await model.changeShortcut {
                try await SkhdShortcuts(integrations: model.backend).rebind(
                    id: params.id, revision: params.revision, chord: params.chord)
            }
        }
        register("shortcuts.disable") { [weak model] (params: ShortcutDisableParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return try await model.changeShortcut {
                try await SkhdShortcuts(integrations: model.backend).disable(
                    id: params.id, revision: params.revision)
            }
        }
        register("shortcuts.reset") { [weak model] (params: ShortcutResetParams) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            return try await model.changeShortcut {
                try await SkhdShortcuts(integrations: model.backend).reset(
                    revision: params.revision)
            }
        }
        register("shortcuts.openConfiguration") { [weak model] (_: Empty) in
            guard let model else { throw BridgeFailure(.unavailable, "The app is closing.") }
            let url = SkhdShortcuts().configURL
            guard NSWorkspace.shared.open(url) else {
                model.log.failure("open skhdrc", "The configuration could not be opened.")
                throw BridgeFailure(.operationFailed, "The configuration could not be opened.")
            }
            model.log.note("open skhdrc", Paths.display(url))
            return Null()
        }
    }
}

extension AppModel {
    func readShortcuts() async throws -> ShortcutsState {
        let snapshot: ShortcutsSnapshot
        do { snapshot = try SkhdShortcuts(integrations: backend).read() } catch {
            log.failure("read shortcuts", error.localizedDescription)
            throw BridgeFailure(
                .operationFailed, "Your shortcuts could not be read: \(error.localizedDescription)")
        }
        return ShortcutsState(snapshot, desktops: await backend.desktopCount())
    }

    func changeShortcut(
        _ operation: () async throws -> CommandResult
    ) async throws -> ShortcutMutation {
        do {
            let result = try await operation()
            log.record(result)
            shortcuts.reload()
            let state = try await readShortcuts()
            StateBroadcast.shared.shortcutsWritten(state)
            return ShortcutMutation(
                state: state, warning: result.ok ? result.stdout : result.stderr)
        } catch {
            log.failure("change shortcut", error.localizedDescription)
            throw BridgeFailure(.operationFailed, error.localizedDescription)
        }
    }
}
