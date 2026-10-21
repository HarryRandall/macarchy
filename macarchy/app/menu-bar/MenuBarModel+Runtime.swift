import Macarchy
import Foundation

extension MenuBarModel {
    var hasChanges: Bool {
        draft != applied || ComponentBoxLayout.normalising(draft, items: items) != draft
    }

    func applyConfiguration(_ configuration: BarConfiguration) async throws {
        let actual = Set(items.map(\.id))
        for component in configuration.components
        where component.isCustom && !actual.contains(component.id) {
            try await send(BarCommands.customArguments(component))
        }
        for component in configuration.components where component.hasBoxLayout {
            for member in component.members
            where member.hasPrefix("gap.") && !actual.contains(member) {
                try await send([
                    "--add", "item", member, component.side, "--set", member, "icon.drawing=off",
                    "label.drawing=off"
                ])
            }
        }
        let removed = applied.components.filter { component in
            component.isCustom && !configuration.components.contains { $0.id == component.id }
        }
        for component in removed where actual.contains(component.id) {
            try await send(["--remove", component.id])
        }
        let arguments = BarCommands.changes(
            configuration, from: applied,
            baseline: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.editableSettings) }))
        if !arguments.isEmpty { try await send(arguments) }
    }

    private func send(_ arguments: [String]) async throws {
        let result = await backend.sketchybar(arguments)
        log.record(result)
        guard result.ok else { throw BorderApplyError(message: result.summary) }
    }

    func readSnapshot(logQuery: Bool = true) async throws -> [String: String] {
        let (result, state) = await backend.barState()
        if logQuery { log.record(result) }
        try Task.checkCancellation()
        guard result.ok, let state else { throw BorderApplyError(message: result.summary) }
        var snapshots: [SketchybarItem] = []
        for name in state.items ?? [] {
            try Task.checkCancellation()
            var result = await backend.sketchybar(["--query", name])
            if !result.ok || SketchybarItem.parse(id: name, json: result.stdout) == nil {
                try await Task.sleep(for: .milliseconds(150))
                result = await backend.sketchybar(["--query", name])
            }
            guard result.ok, let item = SketchybarItem.parse(id: name, json: result.stdout) else {
                throw BorderApplyError(
                    message: "Could not read component \(name). Refresh and try again.")
            }
            snapshots.append(item)
        }
        try Task.checkCancellation()
        if logQuery || !isApplying { replaceSnapshot(snapshots, colour: state.color) }
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
