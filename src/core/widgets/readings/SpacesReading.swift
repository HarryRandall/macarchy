import CoreGraphics
import Foundation

@_silgen_name("CGSMainConnectionID")
private func mainConnection() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func copyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

/// The Spaces yabai knows of, with the apps of each one's windows.
struct SpacesReading: Equatable, Sendable {
    struct Space: Equatable, Sendable {
        /// The system's id for the Space, which yabai reports too.
        var id: Int = 0
        var index: Int
        var display: Int
        /// Showing on its display: the current Space there.
        var visible: Bool
        /// The apps of its windows, left to right and then top to bottom.
        var apps: [String]
    }

    var spaces: [Space]

    static func read(integrations: Integrations = Integrations()) async -> SpacesReading? {
        async let spaces = integrations.execute(Paths.yabai, ["-m", "query", "--spaces"])
        async let windows = integrations.execute(Paths.yabai, ["-m", "query", "--windows"])
        let (spaceList, windowList) = await (spaces, windows)
        guard spaceList.ok, let data = spaceList.stdout.data(using: .utf8),
            var reading = parse(
                spaces: data, windows: windowList.ok ? windowList.stdout.data(using: .utf8) : nil)
        else { return nil }
        // yabai can still report the Space just left as the current one for a
        // moment after a switch; the window server knows straight away.
        if let current = currentSpaceIDs() {
            for index in reading.spaces.indices {
                reading.spaces[index].visible = current.contains(reading.spaces[index].id)
            }
        }
        return reading
    }

    /// The reading with the Spaces whose ids are in `current` showing.
    func showing(ids current: Set<Int>) -> SpacesReading {
        var result = self
        for position in result.spaces.indices {
            result.spaces[position].visible = current.contains(result.spaces[position].id)
        }
        return result
    }

    /// The reading with one of `app`'s windows moved from Space `from` to
    /// Space `to`, shown last there. Unchanged when either Space is missing
    /// or `from` shows no window of `app`.
    func moving(_ app: String, from: Int, to: Int) -> SpacesReading {
        guard from != to,
            let source = spaces.firstIndex(where: { $0.index == from }),
            let target = spaces.firstIndex(where: { $0.index == to }),
            let window = spaces[source].apps.lastIndex(of: app)
        else { return self }
        var result = self
        result.spaces[source].apps.remove(at: window)
        result.spaces[target].apps.append(app)
        return result
    }

    /// The reading with Space `index` as the current one on its display.
    func showing(_ index: Int) -> SpacesReading {
        guard let display = spaces.first(where: { $0.index == index })?.display else { return self }
        var result = self
        for position in result.spaces.indices where result.spaces[position].display == display {
            result.spaces[position].visible = result.spaces[position].index == index
        }
        return result
    }

    /// The id of the Space showing on each display, from the window server,
    /// or nil when it cannot be asked.
    static func currentSpaceIDs() -> Set<Int>? {
        guard let displays = copyManagedDisplaySpaces(mainConnection()) as? [[String: Any]]
        else { return nil }
        let ids = displays.compactMap { display in
            (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int
        }
        return ids.isEmpty ? nil : Set(ids)
    }

    /// Each display's Space ids left to right, with the window server's
    /// identifier for the display: its UUID, or "Main" while displays share
    /// Spaces. Nil when the window server cannot be asked.
    static func displaySpaces() -> [(identifier: String, ids: [Int])]? {
        guard let displays = copyManagedDisplaySpaces(mainConnection()) as? [[String: Any]],
            !displays.isEmpty
        else { return nil }
        return displays.map { display in
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            return (
                display["Display Identifier"] as? String ?? "",
                spaces.compactMap { $0["ManagedSpaceID"] as? Int }
            )
        }
    }

    /// Space ids by index, numbered as yabai does, from the window server
    /// at once rather than from yabai, which answers slowly mid-switch. Nil
    /// with several displays, whose order yabai decides.
    static func indicesFromWindowServer() -> [Int: Int]? {
        guard let displays = copyManagedDisplaySpaces(mainConnection()) as? [[String: Any]],
            displays.count == 1, let spaces = displays[0]["Spaces"] as? [[String: Any]]
        else { return nil }
        let ids = spaces.compactMap { $0["ManagedSpaceID"] as? Int }
        guard !ids.isEmpty, ids.count == spaces.count else { return nil }
        return Dictionary(
            uniqueKeysWithValues: ids.enumerated().map { ($0.offset + 1, $0.element) })
    }

    /// The Spaces in order, each with the apps of the windows a person would
    /// count: standard windows that are not minimised, hidden or on every Space.
    static func parse(spaces: Data, windows: Data?) -> SpacesReading? {
        guard let queried = try? JSONDecoder().decode([QueriedSpace].self, from: spaces) else {
            return nil
        }
        let shown =
            (windows.flatMap { try? JSONDecoder().decode([QueriedWindow].self, from: $0) }
            ?? []).filter(\.counts)
        return SpacesReading(
            spaces: queried.sorted { $0.index < $1.index }.map { space in
                let apps = shown.filter { $0.space == space.index && $0.display == space.display }
                    .sorted { ($0.x, $0.y, $0.stack, $0.id) < ($1.x, $1.y, $1.stack, $1.id) }
                    .compactMap(\.app)
                return Space(
                    id: space.id ?? 0, index: space.index, display: space.display,
                    visible: space.visible, apps: apps)
            })
    }
}

/// App names to the glyph names sketchybar-app-font draws, read from the
/// Spaces widget's `app-icons.json`.
struct AppIcons: Equatable, Sendable {
    var fallback = ":default:"
    var exact: [String: String] = [:]
    /// Names that start with these, checked in order after `exact`.
    var prefixes: [[String]] = []

    func glyph(for app: String) -> String {
        exact[app] ?? prefixes.first { $0.count == 2 && app.hasPrefix($0[0]) }?[1] ?? fallback
    }

    static func load(from directory: URL) -> AppIcons {
        struct File: Decodable {
            var `default`: String?
            var exact: [String: String]?
            var prefixes: [[String]]?
        }
        guard let data = try? Data(contentsOf: directory.appending(path: "app-icons.json")),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else { return AppIcons() }
        return AppIcons(
            fallback: file.default ?? ":default:", exact: file.exact ?? [:],
            prefixes: file.prefixes ?? [])
    }
}

private struct QueriedSpace: Decodable {
    let id: Int?
    let index: Int
    let display: Int
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case id, index, display
        case visible = "is-visible"
    }
}

private struct QueriedWindow: Decodable {
    struct Frame: Decodable {
        let x: Double
        let y: Double
    }

    let id: Int
    let app: String?
    let space: Int
    let display: Int
    let role: String?
    let subrole: String?
    let frame: Frame?
    let stackIndex: Int?
    let hasReference: Bool?
    let minimised: Bool?
    let hidden: Bool?
    let sticky: Bool?

    enum CodingKeys: String, CodingKey {
        case id, app, space, display, role, subrole, frame
        case stackIndex = "stack-index"
        case hasReference = "has-ax-reference"
        case minimised = "is-minimized"
        case hidden = "is-hidden"
        case sticky = "is-sticky"
    }

    var counts: Bool {
        app != nil && role == "AXWindow" && subrole == "AXStandardWindow"
            && hasReference != false && minimised != true && hidden != true && sticky != true
    }

    var x: Double { frame?.x ?? 0 }
    var y: Double { frame?.y ?? 0 }
    var stack: Int { stackIndex ?? 0 }
}
