import Foundation
import Observation
import Macarchy

/// sketchybar's bar geometry and item visibility.
///
/// Bar values hydrate from `sketchybar --query bar`, so the UI reflects what is
/// running rather than what a config file last said.
@MainActor
@Observable
final class MenuBarModel {
    var height: Double = 35
    var position = "top"
    var paddingLeft: Double = 10
    var paddingRight: Double = 10
    var blurRadius: Double = 0
    var cornerRadius: Double = 0
    var yOffset: Double = 0
    var sticky = true
    var color = "0x1000000"

    private(set) var groups: [ItemGroup] = []
    /// Live leaves for the preview. Groups stay script-level for toggles.
    private(set) var items: [SketchybarItem] = []
    private(set) var isHydrating = false
    private(set) var canUndo = false
    private var undoStack: [@MainActor () async -> Void] = []
    private var recordingUndo = true

    /// A source file and the runtime items it creates.
    ///
    /// The two do not correspond one-to-one: `spaces.sh` alone produces eleven
    /// items, so listing runtime items directly would bury the four things you
    /// actually think about behind ten near-identical Space rows.
    struct ItemGroup: Identifiable, Sendable {
        let id: String  // source file stem
        let items: [String]  // runtime item names
        var visible: Bool
    }

    private let backend: Integrations
    private let log: CommandLog
    private var pending: [String: Task<Void, Never>] = [:]
    private let store = SettingsStore()

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    private static var itemsDirectory: URL {
        Paths.home.appending(path: ".config/sketchybar/items")
    }

    func hydrate() async {
        isHydrating = true
        defer { isHydrating = false }

        let (result, bar) = await backend.barState()
        log.record(result)

        if let bar {
            height = Double(bar.height ?? 35)
            position = bar.position ?? "top"
            blurRadius = Double(bar.blurRadius ?? 0)
            paddingLeft = Double(bar.paddingLeft ?? 10)
            paddingRight = Double(bar.paddingRight ?? 10)
            cornerRadius = Double(bar.cornerRadius ?? 0)
            yOffset = Double(bar.yOffset ?? 0)
            sticky = (bar.sticky ?? "on") == "on"
            color = bar.color ?? color
        }

        let names = bar?.items ?? []
        items = await snapshotItems(names)
        rebuildGroups(runtimeItems: names)
    }

    private func snapshotItems(_ names: [String]) async -> [SketchybarItem] {
        var snapped: [SketchybarItem] = []
        snapped.reserveCapacity(names.count)
        for name in names {
            let result = await backend.sketchybar(["--query", name])
            guard result.ok, let item = SketchybarItem.parse(id: name, json: result.stdout) else {
                continue
            }
            snapped.append(item)
        }
        return snapped
    }

    /// Maps runtime items back to the file that declared them by reading the
    /// `--add` lines out of each item script.
    private func rebuildGroups(runtimeItems: [String]) {
        let definitions = BarItems.groups
        let drawing = Set(items.filter(\.drawing).map(\.id))
        var claimed = Set<String>()
        var built: [ItemGroup] = []

        for definition in definitions {
            let owned = runtimeItems.filter { definition.owns($0) }
            guard !owned.isEmpty else { continue }
            claimed.formUnion(owned)

            built.append(
                ItemGroup(
                    id: definition.name,
                    items: owned,
                    visible: owned.contains { drawing.contains($0) }))
        }

        let orphans = runtimeItems.filter { !claimed.contains($0) }
        if !orphans.isEmpty {
            built.append(ItemGroup(id: "other", items: orphans, visible: true))
        }
        groups = built
    }

    // MARK: - Applying

    func applyBar(_ key: String, _ value: String) {
        guard !isHydrating, let env = RCGenerator.envName(forBarKey: key) else { return }
        pending[key]?.cancel()
        pending[key] = Task { [backend, log, store] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            let result = await SettingsApply.shared.apply(values: [env: value], store: store) {
                await backend.sketchybar(["--bar", "\(key)=\(value)"])
            }
            log.record(result)
            if !result.ok { await self.hydrate() }
        }
    }

    func setGroup(_ group: ItemGroup, visible: Bool) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let previous = groups[index].visible
        groups[index].visible = visible
        pushUndo { [weak self] in self?.setGroup(group, visible: previous) }

        Task { [backend, log, items = group.items] in
            var arguments: [String] = []
            for item in items {
                arguments += ["--set", item, "drawing=\(visible ? "on" : "off")"]
            }
            let result = await backend.sketchybar(arguments)
            log.record(result)
            if result.ok {
                do {
                    try self.store.update { settings in
                        for item in items { settings.itemVisibility[item] = visible }
                    }
                } catch { log.note("Save visibility failed", error.localizedDescription) }
            }
            await hydrate()
        }
    }

    func reloadSketchybar() {
        Task { [backend, log] in
            log.record(await backend.restart(.sketchybar))
        }
    }

    func setDrawing(_ id: String, _ drawing: Bool) {
        let previous = items.first { $0.id == id }?.drawing ?? !drawing
        pushUndo { [weak self] in self?.setDrawing(id, previous) }
        Task {
            let result = await backend.sketchybar(["--set", id, "drawing=\(drawing ? "on" : "off")"]
            )
            log.record(result)
            if result.ok {
                do { try store.update { $0.itemVisibility[id] = drawing } } catch {
                    log.note("Save visibility failed", error.localizedDescription)
                }
            }
            await hydrate()
        }
    }

    func setLabel(_ id: String, _ label: String) {
        let previous = items.first { $0.id == id }?.label.value ?? ""
        pushUndo { [weak self] in self?.setLabel(id, previous) }
        Task {
            let result = await backend.sketchybar(["--set", id, "label=\(label)"])
            log.record(result)
            if result.ok {
                do { try store.update { $0.itemLabels[id] = label } } catch {
                    log.note("Save label failed", error.localizedDescription)
                }
            }
            await hydrate()
        }
    }

    /// `before`/`after` follow query order, which is reversed on the right.
    func move(_ source: String, onto target: String) {
        let names = items.map(\.id)
        guard let sourceIndex = names.firstIndex(of: source),
            let targetIndex = names.firstIndex(of: target),
            sourceIndex != targetIndex
        else { return }
        let relation = sourceIndex < targetIndex ? "after" : "before"
        let neighbor = sourceIndex > 0 ? names[sourceIndex - 1] : nil
        let afterNeighbor = sourceIndex + 1 < names.count ? names[sourceIndex + 1] : nil
        pushUndo { [weak self] in
            guard let self else { return }
            if let afterNeighbor {
                await self.moveRaw(source, "before", afterNeighbor)
            } else if let neighbor {
                await self.moveRaw(source, "after", neighbor)
            }
        }
        Task { await moveRaw(source, relation, target) }
    }

    func undoLast() {
        guard let step = undoStack.popLast() else { return }
        canUndo = !undoStack.isEmpty
        recordingUndo = false
        Task {
            await step()
            recordingUndo = true
        }
    }

    private func pushUndo(_ step: @escaping @MainActor () async -> Void) {
        guard recordingUndo else { return }
        undoStack.append(step)
        canUndo = true
    }

    private func moveRaw(_ source: String, _ relation: String, _ target: String) async {
        let result = await backend.sketchybar(["--move", source, relation, target])
        log.record(result)
        guard result.ok else { return }
        persistOrder(moving: source, onto: target, relation: relation)
        await hydrate()
    }

    private func persistOrder(moving source: String, onto target: String, relation: String) {
        var names = items.map(\.id)
        guard let from = names.firstIndex(of: source) else { return }
        names.remove(at: from)
        guard let to = names.firstIndex(of: target) else { return }
        names.insert(source, at: relation == "after" ? to + 1 : to)
        do { try store.update { $0.itemOrder = names } } catch {
            log.note("Save order failed", error.localizedDescription)
        }
    }
}
