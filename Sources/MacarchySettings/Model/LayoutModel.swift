import Foundation
import Observation

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

    private let backend: StackBackend
    private let log: CommandLog
    private var pending: [String: Task<Void, Never>] = [:]
    private let store = SettingsStore()

    /// Long enough to swallow a slider drag, short enough to feel immediate.
    private let debounce = Duration.milliseconds(80)

    init(backend: StackBackend, log: CommandLog) {
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
        persistHydrated(results)
    }

    /// Mirrors what the daemon is actually running into settings.env, so the
    /// generated yabairc reproduces the live state rather than falling back to
    /// compiled-in defaults that may not match.
    private func persistHydrated(_ results: [CommandResult]) {
        let ordered = ["window_gap", "top_padding", "layout", "split_type", "window_placement",
                       "auto_balance", "mouse_modifier", "mouse_follows_focus", "mouse_drop_action"]
        var values = store.load()
        for (key, result) in zip(ordered, results) where result.ok && !result.stdout.isEmpty {
            guard let env = RCGenerator.envName(forYabaiKey: key) else { continue }
            values[env] = result.stdout
        }
        // Padding is linked in the UI but four separate keys in yabai.
        if let top = values["YABAI_TOP_PADDING"] {
            for edge in ["YABAI_BOTTOM_PADDING", "YABAI_LEFT_PADDING", "YABAI_RIGHT_PADDING"] {
                values[edge] = values[edge] ?? top
            }
        }
        do { try store.write(values) }
        catch { log.note("settings.env seed failed", error.localizedDescription) }
    }

    /// Apply a key to the running daemon, coalescing rapid changes per key.
    ///
    /// Applying and persisting are deliberately separate: the daemon gets the
    /// value immediately so the desktop responds, and settings.env is written
    /// on the same beat so the generated yabairc reproduces it at next login.
    func apply(_ key: String, _ value: String) {
        guard !isHydrating else { return }
        pending[key]?.cancel()
        pending[key] = Task { [backend, log, debounce, store] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            let result = await backend.yabaiWrite(key, value: value)
            log.record(result)
            guard result.ok else { return }

            if let env = RCGenerator.envName(forYabaiKey: key) {
                do { try store.set(env, value) }
                catch { log.note("settings.env write failed", error.localizedDescription) }
            }
        }
    }

    func applyPadding(_ value: Double) {
        let rendered = String(Int(value))
        let edges = linkPadding
            ? ["top_padding", "bottom_padding", "left_padding", "right_padding"]
            : ["top_padding"]
        for edge in edges { apply(edge, rendered) }
    }
}
