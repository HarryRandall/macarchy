import CoreGraphics
import Foundation
import SpaceGesture

extension SpaceSwitcher.Desktop {
    /// The real desktop. An isolated run never posts events, and yabai's
    /// commands go through `Integrations`, which refuses them there too.
    public static func live(integrations: Integrations = Integrations()) -> Self {
        let yabai = Paths.yabai
        return Self(
            layout: { await layout(integrations) },
            showing: { SpacesReading.currentSpaceIDs() ?? [] },
            gesturesAllowed: { !DesktopIsolation.isActive && sg_can_post_events() },
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
                    yabai, ["-m", "query", "--windows", "id", "--window"])
                guard result.ok,
                    let window = try? JSONDecoder().decode(
                        Window.self, from: Data(result.stdout.utf8))
                else { return nil }
                return window.id
            },
            moveWindow: { window, space in
                await integrations.execute(
                    yabai, ["-m", "window", String(window), "--space", String(space)]
                ).ok
            },
            focusWindow: { window in
                _ = await integrations.execute(yabai, ["-m", "window", "--focus", String(window)])
            },
            pause: { try? await Task.sleep(for: .milliseconds(10)) })
    }

    private struct Window: Decodable {
        let id: Int
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
    /// A switcher for the real desktop.
    public static func live(integrations: Integrations = Integrations()) -> SpaceSwitcher {
        SpaceSwitcher(desktop: .live(integrations: integrations))
    }
}
