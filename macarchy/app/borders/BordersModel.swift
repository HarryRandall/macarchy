import Foundation
import Observation
import Macarchy

@MainActor
@Observable
final class BordersModel {
    var width: Double = 6.0
    var visible = true
    var excludedApps = BorderAppearance().excludedApps

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

    let backend: Integrations
    private let log: CommandLog
    private let store = SettingsStore()

    init(backend: Integrations, log: CommandLog) {
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
        let values: [String: String]
        do { values = try store.load() } catch {
            log.note("Settings unreadable", error.localizedDescription); return
        }
        if let raw = values["BORDER_WIDTH"], let parsed = Double(raw) { width = parsed }
        if let raw = values["BORDERS_VISIBLE"] { visible = raw != "false" }
        excludedApps = (values["BORDERS_BLACKLIST"] ?? "iPhone Mirroring")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
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

}
