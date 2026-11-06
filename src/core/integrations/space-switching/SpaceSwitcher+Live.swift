import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import SpaceGesture

extension SpaceSwitcher.Desktop {
    /// The real desktop. An isolated run never posts events, and yabai's
    /// commands go through `Integrations`, which refuses them there too.
    /// `windowMoved` hears each window a move sends to another Space.
    public static func live(
        integrations: Integrations = Integrations(),
        windowMoved: @escaping @Sendable (SpaceSwitcher.Window, Int) async -> Void = { _, _ in }
    ) -> Self {
        let yabai = Paths.yabai
        return Self(
            // An isolated run must not judge by the real desktop's Spaces, so
            // without a layout every switch goes to its fake yabai.
            layout: { DesktopIsolation.isActive ? nil : await layout(integrations) },
            showing: { SpacesReading.currentSpaceIDs() ?? [] },
            gesturesAllowed: { SpaceSwitcher.gesturesAllowed },
            overlayOpen: { sg_overlay_open() },
            swipe: { direction, steps in
                guard !DesktopIsolation.isActive, steps > 0 else { return false }
                return sg_switch(
                    direction == .right ? SGDirectionRight : SGDirectionLeft, UInt32(steps))
            },
            yabaiFocus: { index in
                _ = await integrations.execute(yabai, ["-m", "space", "--focus", String(index)])
            },
            focusedWindow: {
                let result = await integrations.execute(
                    yabai, ["-m", "query", "--windows", "id,app,space", "--window"])
                guard result.ok,
                    let window = try? JSONDecoder().decode(
                        Window.self, from: Data(result.stdout.utf8))
                else { return nil }
                return SpaceSwitcher.Window(id: window.id, app: window.app, space: window.space)
            },
            moveWindow: { window, space in
                await integrations.execute(
                    yabai, ["-m", "window", String(window), "--space", String(space)]
                ).ok
            },
            windowMoved: windowMoved,
            focusWindow: { window in
                _ = await integrations.execute(yabai, ["-m", "window", "--focus", String(window)])
            },
            pause: { try? await Task.sleep(for: .milliseconds(10)) },
            dock: {
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
                    .first.map { Int($0.processIdentifier) }
            },
            focusedSpace: {
                let result = await integrations.execute(
                    yabai, ["-m", "query", "--spaces", "--space"])
                guard result.ok else { return nil }
                return try? JSONDecoder().decode(Space.self, from: Data(result.stdout.utf8)).index
            },
            windows: {
                let result = await integrations.execute(yabai, ["-m", "query", "--windows"])
                guard result.ok,
                    let windows = try? JSONDecoder().decode(
                        [QueriedWindow].self, from: Data(result.stdout.utf8))
                else { return nil }
                return windows.filter(\.carried).map(\.placed)
            },
            toggleFloat: { window in
                _ = await integrations.execute(
                    yabai, ["-m", "window", String(window), "--toggle", "float"])
            },
            swapWindows: { first, second in
                _ = await integrations.execute(
                    yabai, ["-m", "window", String(first), "--swap", String(second)])
            })
    }

    /// A window from yabai's query, for swapping desktops.
    private struct QueriedWindow: Decodable {
        struct Frame: Decodable {
            let x: Double
            let y: Double
        }

        let id: Int
        let app: String
        let space: Int
        let frame: Frame
        let floating: Bool
        let sticky: Bool
        let minimized: Bool
        let hidden: Bool
        let focused: Bool
        let reachable: Bool

        enum CodingKeys: String, CodingKey {
            case id, app, space, frame
            case floating = "is-floating"
            case sticky = "is-sticky"
            case minimized = "is-minimized"
            case hidden = "is-hidden"
            case focused = "has-focus"
            case reachable = "has-ax-reference"
        }

        /// Sticky windows are on every desktop, and yabai cannot move
        /// minimised or hidden ones, or any it has no accessibility handle for.
        var carried: Bool { !sticky && !minimized && !hidden && reachable }

        var placed: SpaceSwitcher.PlacedWindow {
            SpaceSwitcher.PlacedWindow(
                id: id, app: app, space: space, floating: floating, focused: focused,
                x: frame.x, y: frame.y)
        }
    }

    private struct Window: Decodable {
        let id: Int
        let app: String
        let space: Int
    }

    private struct Space: Decodable {
        let id: Int
        let index: Int
    }

    /// With one display the window server has everything at once. With
    /// several, yabai decides the order the indices run in, so it is asked,
    /// and the window server says which Spaces share the pointer's display.
    private static func layout(_ integrations: Integrations) async -> SpaceSwitcher.Layout? {
        guard let displays = SpacesReading.displaySpaces() else { return nil }
        if displays.count == 1 {
            let ids = displays[0].ids
            return SpaceSwitcher.Layout(
                ids: Dictionary(
                    uniqueKeysWithValues: ids.enumerated().map { ($0.offset + 1, $0.element) }),
                pointerDisplay: ids)
        }
        let result = await integrations.execute(Paths.yabai, ["-m", "query", "--spaces"])
        guard result.ok,
            let spaces = try? JSONDecoder().decode([Space].self, from: Data(result.stdout.utf8))
        else { return nil }
        let pointer = pointerDisplayIdentifier()
        return SpaceSwitcher.Layout(
            ids: Dictionary(
                spaces.map { ($0.index, $0.id) }, uniquingKeysWith: { first, _ in first }),
            // Not knowing the pointer's display leaves every switch to yabai.
            pointerDisplay: displays.first { $0.identifier == pointer }?.ids ?? [])
    }

    /// The UUID of the display under the pointer, as the window server names it.
    private static func pointerDisplayIdentifier() -> String? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        var display: CGDirectDisplayID = 0
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(location, 1, &display, &count) == .success, count > 0,
            let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}

extension SpaceSwitcher {
    /// Whether this process may send the instant swipe. Never in an isolated
    /// run.
    ///
    /// Allowing a process under Accessibility lets it post events, but
    /// `CGPreflightPostEventAccess` keeps the answer it gave first until the
    /// process restarts, while `AXIsProcessTrusted` sees the change at once.
    public static var gesturesAllowed: Bool {
        !DesktopIsolation.isActive && (AXIsProcessTrusted() || sg_can_post_events())
    }

    /// Asks macOS to let this process post events, showing its prompt the
    /// first time only. Never in an isolated run.
    @discardableResult
    public static func requestPermission() -> Bool {
        guard !DesktopIsolation.isActive else { return false }
        return sg_request_post_events()
    }

    /// A switcher for the real desktop.
    public static func live(
        integrations: Integrations = Integrations(),
        windowMoved: @escaping @Sendable (Window, Int) async -> Void = { _, _ in }
    ) -> SpaceSwitcher {
        SpaceSwitcher(desktop: .live(integrations: integrations, windowMoved: windowMoved))
    }
}
