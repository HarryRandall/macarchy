import Foundation
import Observation
import Macarchy

/// Live yabai layout settings.
///
/// Values are read from the running daemon rather than parsed out of `yabairc`,
/// so the UI can never drift from what is actually in effect. Dragging a slider
/// applies immediately; persistence happens on commit, not on every frame.
@MainActor
@Observable
final class LayoutModel {
    var windowGap: Double = 8
    var padding: Double = 8
    var linkPadding = true
    var layout = "bsp"
    var splitType = "auto"
    var windowPlacement = "second_child"
    var autoBalance = false
    var mouseModifier = "ctrl"
    var mouseFollowsFocus = false
    var mouseDropAction = "stack"

    private(set) var isHydrating = false

    private let backend: Integrations
    private let log: CommandLog
    private var pending: [String: Task<Void, Never>] = [:]
    private let store = SettingsStore()

    /// Long enough to swallow a slider drag, short enough to feel immediate.
    private let debounce = Duration.milliseconds(80)

    init(backend: Integrations, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    func hydrate() async {
        isHydrating = true
        defer { isHydrating = false }

        async let gap = backend.yabaiRead("window_gap")
        async let top = backend.yabaiRead("top_padding")
        async let mode = backend.yabaiRead("layout")
        async let split = backend.yabaiRead("split_type")
        async let placement = backend.yabaiRead("window_placement")
        async let balance = backend.yabaiRead("auto_balance")
        async let modifier = backend.yabaiRead("mouse_modifier")
        async let follows = backend.yabaiRead("mouse_follows_focus")
        async let drop = backend.yabaiRead("mouse_drop_action")

        let results = await [gap, top, mode, split, placement, balance, modifier, follows, drop]

        guard results.allSatisfy(\.ok) else {
            for result in results where !result.ok { log.record(result) }
            return
        }
        if let value = Double(results[0].stdout) { windowGap = value }
        if let value = Double(results[1].stdout) { padding = value }
        if !results[2].stdout.isEmpty { layout = results[2].stdout }
        if !results[3].stdout.isEmpty { splitType = results[3].stdout }
        if !results[4].stdout.isEmpty { windowPlacement = results[4].stdout }
        autoBalance = results[5].stdout == "on"
        if !results[6].stdout.isEmpty { mouseModifier = results[6].stdout }
        mouseFollowsFocus = results[7].stdout != "off"
        if !results[8].stdout.isEmpty { mouseDropAction = results[8].stdout }

        log.note("hydrated layout", "\(results.count) keys read from yabai")
    }

    /// Apply a key to the running daemon, coalescing rapid changes per key.
    ///
    /// Applying and persisting are deliberately separate: the daemon gets the
    /// value immediately so the desktop responds, and JSON is written
    /// on the same beat so the generated yabairc reproduces it at next login.
    func apply(_ key: String, _ value: String) {
        guard !isHydrating else { return }
        pending[key]?.cancel()
        pending[key] = Task { [backend, log, debounce, store] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            guard let env = RCGenerator.envName(forYabaiKey: key) else { return }
            let result = await SettingsApply.shared.apply(values: [env: value], store: store) {
                await backend.yabaiWrite(key, value: value)
            }
            log.record(result)
            if !result.ok { await self.hydrate() }

        }
    }

    func applyPadding(_ value: Double) {
        let rendered = String(Int(value))
        let edges =
            linkPadding
            ? ["top_padding", "bottom_padding", "left_padding", "right_padding"]
            : ["top_padding"]
        for edge in edges { apply(edge, rendered) }
    }
}
