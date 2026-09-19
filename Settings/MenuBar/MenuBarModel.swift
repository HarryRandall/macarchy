import Foundation
import Observation
import Desktop

@MainActor
@Observable
final class MenuBarModel {
    var draft = BarConfiguration()
    private(set) var applied = BarConfiguration()
    private(set) var items: [SketchybarItem] = []
    private(set) var isHydrating = false
    private(set) var isApplying = false
    private(set) var live = false
    var selection: Set<String> = []
    var selected: String? {
        get { selection.count == 1 ? selection.first : nil }
        set { selection = newValue.map { [$0] } ?? [] }
    }
    var selectedComponents: [BarComponent] {
        draft.components.filter { selection.contains($0.id) }
    }

    func select(_ id: String, extending: Bool = false) {
        if extending {
            if !selection.insert(id).inserted { selection.remove(id) }
        } else {
            selection = [id]
        }
    }

    func selectAll() { selection = Set(draft.components.map(\.id)) }

    func updateSelection(_ change: (inout BarComponent) -> Void) {
        let ids = selection
        edit { configuration in
            for index in configuration.components.indices
            where ids.contains(configuration.components[index].id) {
                change(&configuration.components[index])
            }
        }
    }
    var side = "right"
    var error: String?
    var colour = "0x01000000"
    private var undoStack: [BarConfiguration] = []
    private var pending: Task<Void, Never>?
    let backend: StackBackend
    let log: CommandLog
    let configurationStore: BarConfigurationStore
    let settingsStore: SettingsEnv

    var hasChanges: Bool { draft != applied }
    var canUndo: Bool { !undoStack.isEmpty && !isApplying }
    var height: Double { Double(draft.geometry["height"] ?? "35") ?? 35 }
    var selectedComponent: BarComponent? { draft.components.first { $0.id == selected } }

    init(
        backend: StackBackend, log: CommandLog,
        configurationStore: BarConfigurationStore = BarConfigurationStore(),
        settingsStore: SettingsEnv = SettingsEnv()
    ) {
        self.backend = backend
        self.log = log
        self.configurationStore = configurationStore
        self.settingsStore = settingsStore
    }

    func replaceSnapshot(_ snapshots: [SketchybarItem], colour: String?) {
        items = snapshots
        if let colour { self.colour = colour }
    }

    func hydrate() async {
        guard !isHydrating, !isApplying, !hasChanges else { return }
        isHydrating = true
        defer { isHydrating = false }
        do {
            let geometry = try await readSnapshot()
            let saved = try configurationStore.load()
            draft = MenuBarComponents.merge(
                saved, discovered: MenuBarComponents.discover(items), geometry: geometry)
            applied = draft
            if let recovered = try configurationStore.loadDraft() {
                draft = MenuBarComponents.merge(
                    recovered, discovered: MenuBarComponents.discover(items),
                    geometry: recovered.geometry)
            }
            draft.componentPadding = draft.padding
            draft.componentSpacing = draft.spacing
            if selected == nil { selected = draft.components.first { $0.side == side }?.id }
        } catch { self.error = error.localizedDescription }
    }

    func edit(_ change: (inout BarConfiguration) -> Void) {
        guard !isApplying, !isHydrating else { return }
        let old = draft
        change(&draft)
        guard draft != old else { return }
        undoStack.append(old)
        if undoStack.count > 40 { undoStack.removeFirst() }
        persistDraft()
        schedule()
    }

    func update(_ id: String, _ change: (inout BarComponent) -> Void) {
        edit { configuration in
            guard let index = configuration.components.firstIndex(where: { $0.id == id }) else {
                return
            }
            change(&configuration.components[index])
        }
    }

    func move(_ id: String, before target: String) {
        let ids = selection.contains(id) ? selection : [id]
        edit { $0.move(ids, before: target) }
        selection = ids
        side = selectedComponent?.side ?? side
    }

    func moveToSide(_ id: String, side: String) {
        let ids = selection.contains(id) ? selection : [id]
        edit { $0.moveToSide(ids, side: side) }
        self.side = side
    }

    func undoLast() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        draft = previous
        persistDraft()
        schedule()
    }

    func discard() {
        guard !isApplying else { return }
        pending?.cancel()
        draft = applied
        try? configurationStore.clearDraft()
        undoStack.removeAll()
        error = nil
    }

    func setLive(_ enabled: Bool) {
        guard !enabled || (!isApplying && !hasChanges) else { return }
        if !isApplying { pending?.cancel() }
        live = enabled
    }

    private func persistDraft() {
        do { try configurationStore.saveDraft(draft) } catch {
            self.error = "Could not save the draft: \(error.localizedDescription)"
        }
    }

    private func schedule() {
        pending?.cancel()
        guard live, hasChanges else { return }
        pending = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await apply()
        }
    }

    func add(kind: String) {
        let id = "macarchy." + UUID().uuidString.lowercased()
        var component = BarComponent(id: id, title: kind.capitalized, side: side, members: [id])
        component.kind = kind
        component.text = kind == "text" ? "Hello" : ""
        component.icon = kind == "icon" ? "★" : ""
        edit { $0.components.append(component) }
        selected = id
    }

    func removeCustom(_ id: String) {
        guard draft.components.first(where: { $0.id == id })?.isCustom == true else { return }
        edit { $0.components.removeAll { $0.id == id } }
        selected = nil
    }

    func apply() async {
        guard !isApplying, hasChanges else { return }
        isApplying = true
        error = nil
        let submitted = draft
        do {
            _ = try await readSnapshot()
            try await applyConfiguration(submitted)
            try configurationStore.save(submitted)
            var values = settingsStore.load()
            for (key, value) in submitted.geometry {
                if let env = RCGenerator.envName(forBarKey: key) { values[env] = value }
            }
            values.removeValue(forKey: "SKETCHYBAR_ITEM_ORDER")
            try settingsStore.write(values)
            applied = submitted
            try configurationStore.clearDraft()
            _ = try await readSnapshot()
        } catch {
            self.error =
                "Apply did not finish. Some changes may be live. \(error.localizedDescription) Retry Apply to finish."
            live = false
        }
        isApplying = false
    }
}
