import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class MenuBarModel {
    var draft = BarConfiguration()
    private(set) var applied = BarConfiguration()
    private(set) var items: [SketchybarItem] = []
    private(set) var isHydrating = false
    private(set) var isApplying = false
    private(set) var live = false
    private(set) var lastObservedAt: Date?
    private(set) var observationError: String?
    private var isObserving = false
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
    private var interactionStart: BarConfiguration?
    private var undoStack: [BarConfiguration] = []
    private var pending: Task<Void, Never>?
    let backend: Integrations
    let log: CommandLog
    let configurationStore: BarConfigurationStore

    var canUndo: Bool { !undoStack.isEmpty && !isApplying }
    var height: Double { Double(draft.geometry["height"] ?? "35") ?? 35 }
    var selectedComponent: BarComponent? { draft.components.first { $0.id == selected } }

    init(
        backend: Integrations, log: CommandLog,
        configurationStore: BarConfigurationStore = BarConfigurationStore()
    ) {
        self.backend = backend
        self.log = log
        self.configurationStore = configurationStore
    }

    func replaceSnapshot(_ snapshots: [SketchybarItem], colour: String?) {
        items = snapshots
        lastObservedAt = Date()
        observationError = nil
        if let colour { self.colour = colour }
    }

    /// Readings refresh independently of authored settings, including while a draft is open.
    func refreshReadings() async {
        guard !isObserving, !isHydrating, !isApplying else { return }
        if draft.components.isEmpty { await hydrate(); return }
        isObserving = true
        defer { isObserving = false }
        do {
            _ = try await readSnapshot(logQuery: false)
        } catch is CancellationError {
            return
        } catch {
            observationError = error.localizedDescription
        }
    }

    /// The view owns this task, so leaving the page cancels polling.
    func observeWhileVisible() async {
        await hydrate()
        var tick = 0
        while !Task.isCancelled {
            if tick % 8 == 0 { await refreshReadings() } else { await refreshSelectedReadings() }
            tick += 1
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
    }

    /// Only the selected widget needs a fast cadence; full sweeps are less frequent.
    private func refreshSelectedReadings() async {
        guard !isObserving, !isHydrating, !isApplying, let component = selectedComponent else {
            return
        }
        isObserving = true
        defer { isObserving = false }
        do {
            var updates: [SketchybarItem] = []
            for id in component.members where !id.hasPrefix("gap.") {
                try Task.checkCancellation()
                let result = await backend.sketchybar(["--query", id])
                guard result.ok, let item = SketchybarItem.parse(id: id, json: result.stdout) else {
                    throw BorderApplyError(message: "Could not read \(component.title).")
                }
                updates.append(item)
            }
            guard !Task.isCancelled, !isApplying else { return }
            let replacements = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, $0) })
            replaceSnapshot(items.map { replacements[$0.id] ?? $0 }, colour: nil)
        } catch is CancellationError {
            return
        } catch { observationError = error.localizedDescription }
    }

    func hydrate() async {
        guard !isHydrating, !isApplying, !hasChanges else { return }
        isHydrating = true
        error = nil
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
            if selected == nil { selected = draft.components.first { $0.side == side }?.id }
        } catch { self.error = error.localizedDescription }
    }

    /// Applies a change to the draft.
    ///
    /// Only hydrating blocks an edit, because that is the one moment the draft
    /// is being replaced wholesale. Applying used to block too, and an apply
    /// holds its flag across two full `--query` sweeps — so every slider tick
    /// and colour drag during that window was silently discarded.
    func edit(_ change: (inout BarConfiguration) -> Void) {
        guard !isHydrating else { return }
        let old = draft
        // Controls may read the current draft while calculating an edit. Mutate
        // a separate value so those reads never overlap an inout write.
        var edited = old
        change(&edited)
        edited = ComponentBoxLayout.applyingPaddingChange(edited, from: old, items: items)
        edited = ComponentBoxLayout.normalising(edited, items: items)
        guard edited != old else { return }
        draft = edited
        if interactionStart == nil { undoStack.append(old) }
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

    func beginInteraction() {
        if interactionStart == nil { interactionStart = draft }
    }

    func endInteraction() {
        guard let original = interactionStart else { return }
        interactionStart = nil
        if original != draft { undoStack.append(original) }
        if undoStack.count > 40 { undoStack.removeFirst() }
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
        draft = ComponentBoxLayout.normalising(draft, items: items)
        isApplying = true
        error = nil
        let submitted = draft
        do {
            try await OperationLock.run(root: configurationStore.directory) { [self] in
                try submitted.validate()
                _ = try await readSnapshot()
                try await applyConfiguration(submitted)
                try configurationStore.save(submitted)
            }
            applied = submitted
            // Edits are no longer blocked while applying, so the draft may
            // have moved on. Clearing it then would throw those away.
            if draft == submitted { try configurationStore.clearDraft() }
            _ = try await readSnapshot()
        } catch {
            self.error =
                "Apply did not finish. Some changes may be live. \(error.localizedDescription) Retry Apply to finish."
            live = false
        }
        isApplying = false
        // Anything changed mid-flight is still outstanding; pick it up now
        // rather than waiting for the next edit to notice.
        if hasChanges { schedule() }
    }
}
