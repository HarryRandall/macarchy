import Foundation
import Observation

/// sketchybar's bar geometry and item visibility.
///
/// Bar values hydrate from `sketchybar --query bar`, so the UI reflects what is
/// running rather than what a config file last said.
@MainActor
@Observable
final class MenuBarModel {
    var height: Double = 25
    var position = "top"
    var paddingLeft: Double = 20
    var paddingRight: Double = 20
    var blurRadius: Double = 0
    var cornerRadius: Double = 0
    var yOffset: Double = 0
    var sticky = true

    private(set) var groups: [ItemGroup] = []
    private(set) var isHydrating = false

    /// A source file and the runtime items it creates.
    ///
    /// The two do not correspond one-to-one: `spaces.sh` alone produces eleven
    /// items, so listing runtime items directly would bury the four things you
    /// actually think about behind ten near-identical Space rows.
    struct ItemGroup: Identifiable, Sendable {
        let id: String          // source file stem
        let items: [String]     // runtime item names
        var visible: Bool
    }

    private let backend: StackBackend
    private let log: CommandLog
    private var pending: [String: Task<Void, Never>] = [:]
    private let store = SettingsStore()

    init(backend: StackBackend, log: CommandLog) {
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
            height = Double(bar.height ?? 25)
            position = bar.position ?? "top"
            blurRadius = Double(bar.blurRadius ?? 0)
            paddingLeft = Double(bar.paddingLeft ?? 20)
            paddingRight = Double(bar.paddingRight ?? 20)
            cornerRadius = Double(bar.cornerRadius ?? 0)
            yOffset = Double(bar.yOffset ?? 0)
            sticky = (bar.sticky ?? "on") == "on"
        }

        if bar != nil { persistHydrated() }
        await rebuildGroups(runtimeItems: bar?.items ?? [])
    }

    /// Maps runtime items back to the file that declared them by reading the
    /// `--add` lines out of each item script.
    private func rebuildGroups(runtimeItems: [String]) async {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: Self.itemsDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "sh" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var claimed = Set<String>()
        var built: [ItemGroup] = []

        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let declared = Self.declaredNames(in: text)
            // A script may declare prefixes that expand at runtime (space.1 …),
            // so match on prefix as well as exact name.
            let owned = runtimeItems.filter { item in
                declared.contains(item) || declared.contains { item.hasPrefix($0 + ".") }
            }
            guard !owned.isEmpty else { continue }
            claimed.formUnion(owned)

            var anyVisible = false
            for item in owned where await isDrawing(item) { anyVisible = true; break }

            built.append(ItemGroup(id: file.deletingPathExtension().lastPathComponent,
                                   items: owned,
                                   visible: anyVisible))
        }

        let orphans = runtimeItems.filter { !claimed.contains($0) }
        if !orphans.isEmpty {
            built.append(ItemGroup(id: "other", items: orphans, visible: true))
        }
        groups = built
    }

    private static func declaredNames(in script: String) -> [String] {
        var names: [String] = []
        // Matches: --add item battery right / --add bracket cpu.bracket …
        let pattern = #"--add\s+(?:item|bracket|alias|graph|space)\s+([A-Za-z0-9._]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(script.startIndex..., in: script)
        for match in regex.matches(in: script, range: range) {
            guard let r = Range(match.range(at: 1), in: script) else { continue }
            var name = String(script[r])
            // Strip a trailing dot-suffix so "space.1" maps back to "space".
            if let dot = name.firstIndex(of: "."), name.hasPrefix("space") { name = String(name[..<dot]) }
            names.append(name)
        }
        return names
    }

    private func isDrawing(_ item: String) async -> Bool {
        let result = await CommandRunner.run(Paths.sketchybar, ["--query", item])
        guard result.ok, let data = result.stdout.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let geometry = object["geometry"] as? [String: Any],
              let drawing = geometry["drawing"] as? String
        else { return true }
        return drawing == "on"
    }

    /// Mirrors the running bar into settings.env so the generated rc reproduces
    /// it. The file and the live bar had already diverged — sketchybarrc said
    /// height 37 while the bar was running 35 — so a restart silently reverted.
    private func persistHydrated() {
        var values = store.load()
        let live: [String: String] = [
            "height": String(Int(height)), "position": position,
            "padding_left": String(Int(paddingLeft)), "padding_right": String(Int(paddingRight)),
            "blur_radius": String(Int(blurRadius)), "corner_radius": String(Int(cornerRadius)),
            "y_offset": String(Int(yOffset)), "sticky": sticky ? "on" : "off"
        ]
        for (key, value) in live {
            guard let env = RCGenerator.envName(forBarKey: key) else { continue }
            values[env] = value
        }
        do { try store.write(values) }
        catch { log.note("settings.env seed failed", error.localizedDescription) }
    }

    // MARK: - Applying

    func applyBar(_ key: String, _ value: String) {
        guard !isHydrating else { return }
        pending[key]?.cancel()
        pending[key] = Task { [backend, log] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            _ = backend
            log.record(await CommandRunner.run(Paths.sketchybar, ["--bar", "\(key)=\(value)"]))
        }
        if let env = RCGenerator.envName(forBarKey: key) {
            try? store.set(env, value)
        }
    }

    func setGroup(_ group: ItemGroup, visible: Bool) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index].visible = visible

        Task { [log, items = group.items] in
            var arguments: [String] = []
            for item in items {
                arguments += ["--set", item, "drawing=\(visible ? "on" : "off")"]
            }
            log.record(await CommandRunner.run(Paths.sketchybar, arguments))
        }
    }

    func reloadSketchybar() {
        Task { [log] in
            log.record(await CommandRunner.run(
                Paths.launchctl,
                ["kickstart", "-k", "gui/\(getuid())/homebrew.mxcl.sketchybar"]))
        }
    }
}
