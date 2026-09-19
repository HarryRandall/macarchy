import Foundation
import Observation

@MainActor
@Observable
final class BordersModel {
    var width: Double = 6.0
    var visible = true
    var blacklist: [String] = []

    /// Global window corner radius (`NSConvolutionOverride1`).
    ///
    /// Not per-app, and not universal: only native AppKit windows honour it.
    /// Chromium apps and Firefox draw their own corners and ignore it entirely.
    var cornerRadius: Double = 0.5
    var cornerRadiusApplied: Double?

    /// Border shape is not an independent choice — a rounded border around a
    /// square window (or the reverse) is always wrong. It follows the radius.
    ///
    /// Below a point the window is visually square, so the border is squared to
    /// match; above it the renderer's `round` mode tracks each window's own
    /// radius, which keeps apps that ignore the override correct too.
    var style: String { cornerRadius < Self.squareThreshold ? "square" : "round" }

    static let squareThreshold: Double = 1.0

    private let backend: StackBackend
    private let log: CommandLog
    private let store = SettingsStore()
    private var pending: Task<Void, Never>?
    private var cornerRadiusPending: Task<Void, Never>?

    init(backend: StackBackend, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    /// Values ≤ 0.25 are ignored by the window server and snap back to the
    /// rounded default, so the usable floor is just above that.
    static let cornerRadiusRange: ClosedRange<Double> = 0.3...12.0

    var cornerRadiusNeedsRestart: Bool {
        guard let applied = cornerRadiusApplied else { return false }
        return abs(applied - cornerRadius) > 0.001
    }

    func hydrate() async {
        let values = store.load()
        if let raw = values["BORDER_WIDTH"], let parsed = Double(raw) { width = parsed }
        if let raw = values["BORDERS_VISIBLE"] { visible = raw != "false" }
        if let raw = values["BORDERS_BLACKLIST"], !raw.isEmpty {
            blacklist = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let result = await CommandRunner.run("/usr/bin/defaults", ["read", "-g", "NSConvolutionOverride1"])
        if result.ok, let parsed = Double(result.stdout) {
            cornerRadius = parsed
            cornerRadiusApplied = parsed
        }
    }

    func applyBorders() {
        pending?.cancel()
        let style = self.style
        pending = Task { [backend, log, width, visible, blacklist, store] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            var arguments = [
                "width=\(visible ? String(format: "%.1f", width) : "0.0")",
                "style=\(style)",
                "background_color=0x00000000"
            ]
            var excludedApps = blacklist
            if !excludedApps.contains("iPhone Mirroring") { excludedApps.append("iPhone Mirroring") }
            arguments.append("blacklist=\(excludedApps.joined(separator: ","))")

            if visible {
                let name = (try? String(contentsOf: Paths.themesDirectory.appending(path: ".current"), encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let theme = ThemeCatalog.parseEnv(Paths.themesDirectory.appending(path: name).appending(path: "theme.env"))
                var active = theme["BORDER_ACTIVE"] ?? "0xff45e8ff"
                let colours = (theme["BORDER_ANIMATION_COLORS"] ?? "").split(whereSeparator: { $0.isWhitespace })
                if let first = colours.first {
                    let second = colours.count > 3 ? colours[3] : (colours.count > 1 ? colours[1] : first)
                    active = (theme["BORDER_ANIMATION_EFFECT"] ?? "glow") == "glow"
                        ? "glow(\(first))"
                        : "gradient(top_left=\(first),bottom_right=\(second))"
                }
                arguments.append("active_color=\(active)")
                arguments.append("inactive_color=\(theme["BORDER_INACTIVE"] ?? "0x00000000")")
            } else {
                arguments.append("active_color=0x00000000")
                arguments.append("inactive_color=0x00000000")
            }

            let result = await backend.borders(arguments)
            log.record(result)
            guard result.ok else {
                await self.hydrate()
                return
            }

            do {
                var values = store.load()
                values["BORDER_WIDTH"] = String(format: "%.1f", width)
                values["BORDER_STYLE"] = style
                values["BORDERS_VISIBLE"] = visible ? "true" : "false"
                values["BORDERS_BLACKLIST"] = blacklist.joined(separator: ",")
                try store.write(values)
                log.note("wrote settings.env", "\(values.count) keys")
            } catch {
                log.note("settings.env write failed", error.localizedDescription)
            }
        }
    }

    /// Writes the window radius and re-sends the derived border style together,
    /// so the two can never disagree.
    func applyCornerRadius() {
        cornerRadiusPending?.cancel()
        cornerRadiusPending = Task { [log, cornerRadius] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let result = await CommandRunner.run(
                "/usr/bin/defaults",
                ["write", "-g", "NSConvolutionOverride1", "-float", String(format: "%.2f", cornerRadius)])
            log.record(result)
            guard !Task.isCancelled else { return }
            await MainActor.run { self.applyBorders() }
        }
    }

    func resetCornerRadius() async {
        let result = await CommandRunner.run(
            "/usr/bin/defaults", ["delete", "-g", "NSConvolutionOverride1"])
        log.record(result)
        cornerRadius = 0.5
        applyBorders()
    }
}
