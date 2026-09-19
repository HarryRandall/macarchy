import Foundation
import Observation
import Desktop

@MainActor
@Observable
final class BordersModel {
    var width: Double = 6.0
    var visible = true
    var excludedApps: [String] = []

    /// Global window corner radius (`NSConvolutionOverride1`).
    ///
    /// Not per-app, and not universal: only native AppKit windows honour it.
    /// Chromium apps and Firefox draw their own corners and ignore it entirely.
    var cornerRadius: Double = 12.0
    var cornerRadiusApplied: Double?
    var hasCornerRadiusOverride = false

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
    private let store = SettingsEnv()
    private var pending: Task<Void, Never>?
    private var cornerRadiusPending: Task<Void, Never>?

    init(backend: StackBackend, log: CommandLog) {
        self.backend = backend
        self.log = log
    }

    /// Values ≤ 0.25 are ignored by the window server and snap back to the
    /// rounded default, so the usable floor is just above that.
    static let cornerRadiusRange: ClosedRange<Double> = 0.3...12.0

    /// Window-server corner radius. Global, AppKit-only, and ignored at or
    /// below 0.25 — see the Borders pane footer.
    static let cornerRadiusKey = "NSConvolutionOverride1"

    var cornerRadiusNeedsRestart: Bool {
        guard let applied = cornerRadiusApplied else { return false }
        return abs(applied - cornerRadius) > 0.001
    }

    func hydrate() async {
        let values = store.load()
        if let raw = values["BORDER_WIDTH"], let parsed = Double(raw) { width = parsed }
        if let raw = values["BORDERS_VISIBLE"] { visible = raw != "false" }
        if let raw = values["BORDERS_BLACKLIST"], !raw.isEmpty {
            excludedApps = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let result = await backend.globalDefault(Self.cornerRadiusKey)
        if result.ok, let parsed = Double(result.stdout) {
            cornerRadius = parsed
            cornerRadiusApplied = parsed
            hasCornerRadiusOverride = true
        } else if result.ok || result.stderr.contains("does not exist") {
            cornerRadius = Self.cornerRadiusRange.upperBound
            cornerRadiusApplied = Self.cornerRadiusRange.upperBound
            hasCornerRadiusOverride = false
        }
    }

    func applyBorders() {
        pending?.cancel()
        let style = self.style
        pending = Task { [backend, log, width, visible, excludedApps, store] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            var arguments = [
                "width=\(visible ? String(format: "%.1f", width) : "0.0")",
                "style=\(style)",
                "background_color=0x00000000"
            ]
            var excludedApps = excludedApps
            if !excludedApps.contains("iPhone Mirroring") {
                excludedApps.append("iPhone Mirroring")
            }
            arguments.append("blacklist=\(excludedApps.joined(separator: ","))")

            if visible {
                let name =
                    (try? String(
                        contentsOf: Paths.themesDirectory.appending(path: ".current"),
                        encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let theme = EnvFile.parse(
                    Paths.themesDirectory.appending(path: name).appending(path: "theme.env"))
                var active = theme["BORDER_ACTIVE"] ?? "0xff45e8ff"
                let colours = (theme["BORDER_ANIMATION_COLORS"] ?? "").split(whereSeparator: {
                    $0.isWhitespace
                })
                if let first = colours.first {
                    let second =
                        colours.count > 3 ? colours[3] : (colours.count > 1 ? colours[1] : first)
                    active =
                        (theme["BORDER_ANIMATION_EFFECT"] ?? "glow") == "glow"
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
                values["BORDERS_BLACKLIST"] = excludedApps.joined(separator: ",")
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
        cornerRadiusPending = Task { [backend, log, cornerRadius] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let result = await backend.setGlobalDefault(
                Self.cornerRadiusKey, float: String(format: "%.2f", cornerRadius))
            log.record(result)
            guard !Task.isCancelled, result.ok else { return }
            self.hasCornerRadiusOverride = true
            self.applyBorders()
        }
    }

    func resetCornerRadius() async {
        cornerRadiusPending?.cancel()
        let result = await backend.removeGlobalDefault(Self.cornerRadiusKey)
        log.record(result)
        guard result.ok else { return }
        cornerRadius = Self.cornerRadiusRange.upperBound
        hasCornerRadiusOverride = false
        applyBorders()
    }
}
