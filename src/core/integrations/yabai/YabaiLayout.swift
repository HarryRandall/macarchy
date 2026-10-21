import Foundation

/// The yabai layout settings the Layout page edits, in the units it shows.
public struct LayoutValues: Codable, Sendable, Equatable {
    public enum Mode: String, Codable, Sendable { case bsp, stack, float }
    public enum Split: String, Codable, Sendable { case auto, vertical, horizontal }
    public enum Placement: String, Codable, Sendable {
        case secondChild = "second_child"
        case firstChild = "first_child"
    }
    public enum Modifier: String, Codable, Sendable { case ctrl, alt, cmd, shift }
    public enum DropAction: String, Codable, Sendable { case stack, swap }

    public var layout: Mode = .bsp
    public var splitType: Split = .auto
    public var windowPlacement: Placement = .secondChild
    public var autoBalance = false
    public var windowGap: Double = 8
    /// The top edge. The page shows one margin and can write it to every edge.
    public var padding: Double = 8
    public var mouseModifier: Modifier = .ctrl
    public var mouseFollowsFocus = false
    public var mouseDropAction: DropAction = .stack

    public init() {}
}

/// A partial edit. Absent fields are left as they are.
public struct LayoutChanges: Codable, Sendable, Equatable {
    public var layout: LayoutValues.Mode?
    public var splitType: LayoutValues.Split?
    public var windowPlacement: LayoutValues.Placement?
    public var autoBalance: Bool?
    public var windowGap: Double?
    public var padding: Double?
    public var mouseModifier: LayoutValues.Modifier?
    public var mouseFollowsFocus: Bool?
    public var mouseDropAction: LayoutValues.DropAction?

    public init() {}

    static let gapRange = 0.0...32
    static let paddingRange = 0.0...40

    /// yabai config keys and values, in a stable order.
    func yabaiPairs(linkPadding: Bool) throws -> [(key: String, value: String)] {
        var pairs: [(String, String)] = []
        if let layout { pairs.append(("layout", layout.rawValue)) }
        if let splitType { pairs.append(("split_type", splitType.rawValue)) }
        if let windowPlacement { pairs.append(("window_placement", windowPlacement.rawValue)) }
        if let autoBalance { pairs.append(("auto_balance", autoBalance ? "on" : "off")) }
        if let windowGap {
            pairs.append(("window_gap", try Self.points(windowGap, in: Self.gapRange, "gap")))
        }
        if let padding {
            let value = try Self.points(padding, in: Self.paddingRange, "margin")
            let edges =
                linkPadding
                ? ["top_padding", "bottom_padding", "left_padding", "right_padding"]
                : ["top_padding"]
            pairs += edges.map { ($0, value) }
        }
        if let mouseModifier { pairs.append(("mouse_modifier", mouseModifier.rawValue)) }
        if let mouseFollowsFocus {
            // yabai takes on or off here; `autofocus` belongs to focus_follows_mouse.
            pairs.append(("mouse_follows_focus", mouseFollowsFocus ? "on" : "off"))
        }
        if let mouseDropAction { pairs.append(("mouse_drop_action", mouseDropAction.rawValue)) }
        return pairs
    }

    private static func points(
        _ value: Double, in range: ClosedRange<Double>, _ name: String
    ) throws -> String {
        guard value.isFinite, range.contains(value) else {
            throw ConfigurationError(
                "The window \(name) must be between \(Int(range.lowerBound)) and \(Int(range.upperBound)) points."
            )
        }
        return String(Int(value.rounded()))
    }
}

/// What the Layout page shows, and where it came from.
public struct LayoutSnapshot: Sendable, Equatable {
    public enum Source: String, Sendable { case daemon, saved }

    public var values: LayoutValues
    public var source: Source
    /// Why the running daemon could not be read, when `source` is `saved`.
    public var unavailableReason: String?
}

/// Reads and edits yabai's layout settings.
///
/// The running daemon is the source of truth for what is shown, so the page
/// cannot drift from what is in effect. When yabai cannot be reached the saved
/// preferences are shown instead, and edits are refused rather than saved
/// unapplied, because settings are only committed once they have applied.
public struct YabaiLayout: Sendable {
    private let integrations: Integrations
    private let store: SettingsStore

    public init(integrations: Integrations = Integrations(), store: SettingsStore = SettingsStore())
    {
        self.integrations = integrations
        self.store = store
    }

    static let readKeys = [
        "layout", "split_type", "window_placement", "auto_balance", "window_gap", "top_padding",
        "mouse_modifier", "mouse_follows_focus", "mouse_drop_action"
    ]

    /// Never writes. Throws only when the saved settings cannot be read.
    public func read() async throws -> LayoutSnapshot {
        let results = await withTaskGroup(of: (Int, CommandResult).self) { group in
            for (index, key) in Self.readKeys.enumerated() {
                group.addTask { (index, await integrations.yabaiRead(key)) }
            }
            var ordered = [CommandResult?](repeating: nil, count: Self.readKeys.count)
            for await (index, result) in group { ordered[index] = result }
            return ordered.compactMap { $0 }
        }
        if results.allSatisfy(\.ok) {
            let output = Dictionary(
                uniqueKeysWithValues: zip(Self.readKeys, results.map(\.stdout)))
            return LayoutSnapshot(values: Self.values(from: output), source: .daemon)
        }
        let saved = try store.read().flatValues
        let output = Dictionary(
            uniqueKeysWithValues: Self.readKeys.compactMap { key in
                StartupConfiguration.yabaiKeys.first { $0.key == key }.map { setting in
                    (key, saved[setting.env] ?? setting.fallback)
                }
            })
        let failure = results.first { !$0.ok }
        return LayoutSnapshot(
            values: Self.values(from: output), source: .saved,
            unavailableReason: Self.reason(for: failure))
    }

    /// Applies each change to the running daemon, then saves them together.
    ///
    /// The edit is serialised with every other settings change, so a slow
    /// response cannot overwrite a newer value. If one write fails, the ones
    /// before it have already taken effect and nothing is saved; the message
    /// says so.
    public func apply(_ changes: LayoutChanges, linkPadding: Bool) async -> CommandResult {
        let pairs: [(key: String, value: String)]
        do { pairs = try changes.yabaiPairs(linkPadding: linkPadding) } catch {
            return CommandResult(
                command: "layout", status: 1, stderr: error.localizedDescription)
        }
        guard !pairs.isEmpty else { return CommandResult(command: "layout", status: 0) }
        var env: [String: String] = [:]
        for pair in pairs {
            guard let name = StartupConfiguration.envName(forYabaiKey: pair.key) else {
                return CommandResult(
                    command: "layout", status: 1, stderr: "\(pair.key) is not a layout setting.")
            }
            env[name] = pair.value
        }
        let integrations = integrations
        return await SettingsApply.shared.apply(values: env, store: store) {
            var applied: [String] = []
            for pair in pairs {
                let result = await integrations.yabaiWrite(pair.key, value: pair.value)
                guard result.ok else {
                    let detail = result.stderr.isEmpty ? "yabai did not accept it." : result.stderr
                    let prefix =
                        applied.isEmpty
                        ? "" : "Applied \(applied.joined(separator: ", ")) but not saved. "
                    return CommandResult(
                        command: result.command, status: result.status,
                        stderr: "\(prefix)Could not set \(pair.key): \(detail)")
                }
                applied.append(pair.key)
            }
            return CommandResult(
                command: "yabai -m config "
                    + pairs.map { "\($0.key) \($0.value)" }.joined(
                        separator: ", "), status: 0)
        }
    }

    static func values(from output: [String: String]) -> LayoutValues {
        var values = LayoutValues()
        func text(_ key: String) -> String? {
            output[key].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        if let raw = text("layout"), let mode = LayoutValues.Mode(rawValue: raw) {
            values.layout = mode
        }
        if let raw = text("split_type"), let split = LayoutValues.Split(rawValue: raw) {
            values.splitType = split
        }
        if let raw = text("window_placement"), let place = LayoutValues.Placement(rawValue: raw) {
            values.windowPlacement = place
        }
        values.autoBalance = text("auto_balance") == "on"
        if let raw = text("window_gap"), let gap = Double(raw) { values.windowGap = gap }
        if let raw = text("top_padding"), let top = Double(raw) { values.padding = top }
        if let raw = text("mouse_modifier"), let key = LayoutValues.Modifier(rawValue: raw) {
            values.mouseModifier = key
        }
        values.mouseFollowsFocus = (text("mouse_follows_focus") ?? "off") != "off"
        if let raw = text("mouse_drop_action"), let drop = LayoutValues.DropAction(rawValue: raw) {
            values.mouseDropAction = drop
        }
        return values
    }

    private static func reason(for failure: CommandResult?) -> String {
        guard FileManager.default.isExecutableFile(atPath: Paths.yabai) else {
            return
                "yabai isn't installed, so these are your saved settings. Install it to edit them."
        }
        let detail = failure?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = "yabai isn't responding, so these are your saved settings."
        return detail.isEmpty ? base : "\(base) \(detail)"
    }
}

extension LayoutValues {
    /// These values with an edit applied, for keeping a reading current after
    /// an edit succeeds without asking yabai again.
    public func applying(_ changes: LayoutChanges) -> LayoutValues {
        var values = self
        if let layout = changes.layout { values.layout = layout }
        if let split = changes.splitType { values.splitType = split }
        if let placement = changes.windowPlacement { values.windowPlacement = placement }
        if let balance = changes.autoBalance { values.autoBalance = balance }
        if let gap = changes.windowGap { values.windowGap = gap }
        if let padding = changes.padding { values.padding = padding }
        if let modifier = changes.mouseModifier { values.mouseModifier = modifier }
        if let follows = changes.mouseFollowsFocus { values.mouseFollowsFocus = follows }
        if let drop = changes.mouseDropAction { values.mouseDropAction = drop }
        return values
    }
}
