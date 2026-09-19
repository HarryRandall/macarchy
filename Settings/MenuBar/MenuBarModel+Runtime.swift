import Desktop
import Foundation

extension MenuBarModel {
    func applyConfiguration(_ configuration: BarConfiguration) async throws {
        let actual = Set(items.map(\.id))
        for component in configuration.components
        where component.isCustom && !actual.contains(component.id) {
            try await send(BarCommands.customArguments(component))
        }
        let removed = applied.components.filter { component in
            component.isCustom && !configuration.components.contains { $0.id == component.id }
        }
        for component in removed where actual.contains(component.id) {
            try await send(["--remove", component.id])
        }
        let arguments = BarCommands.settings(configuration)
        if !arguments.isEmpty { try await send(arguments) }
    }

    private func send(_ arguments: [String]) async throws {
        let result = await backend.sketchybar(arguments)
        log.record(result)
        guard result.ok else { throw BorderApplyError(message: result.summary) }
    }

    func readSnapshot() async throws -> [String: String] {
        let (result, state) = await backend.barState()
        log.record(result)
        guard result.ok, let state else { throw BorderApplyError(message: result.summary) }
        var snapshots: [SketchybarItem] = []
        for name in state.items ?? [] {
            let result = await backend.sketchybar(["--query", name])
            guard result.ok, let item = SketchybarItem.parse(id: name, json: result.stdout) else {
                throw BorderApplyError(
                    message: "Could not read component \(name). Refresh and try again.")
            }
            snapshots.append(item)
        }
        replaceSnapshot(snapshots, colour: state.color)
        return [
            "height": String(state.height ?? 35), "position": state.position ?? "top",
            "padding_left": String(state.paddingLeft ?? 10),
            "padding_right": String(state.paddingRight ?? 10),
            "blur_radius": String(state.blurRadius ?? 0),
            "corner_radius": String(state.cornerRadius ?? 0),
            "y_offset": String(state.yOffset ?? 0), "sticky": state.sticky ?? "on"
        ]
    }
}
