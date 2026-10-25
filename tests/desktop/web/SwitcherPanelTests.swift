import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

/// Stands in for the screen, so the switcher can open and close without a
/// window appearing.
@MainActor
private final class FakeScreen {
    private(set) var presentations = 0
    private(set) var dismissals = 0
    private var shown = false

    init(_ switcher: ThemeSwitcher) {
        switcher.orderIn = { [weak self] _ in
            self?.presentations += 1
            self?.shown = true
        }
        switcher.orderOut = { [weak self] _ in
            self?.dismissals += 1
            self?.shown = false
        }
        switcher.onScreen = { [weak self] _ in self?.shown ?? false }
    }
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Theme switcher panel")
    struct SwitcherPanelTests {
        @Test("the panel fades, drops input while closing, and reopens at once mid-fade")
        func fades() async throws {
            try await withHarness { harness in
                let (switcher, surface) = try harness.switcherPage(recorder: ThemeRecorder())
                defer { withExtendedLifetime(switcher) {} }
                let screen = FakeScreen(switcher)
                switcher.reduceMotion = { false }
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")

                await switcher.show()
                let panel = try #require(switcher.panel)
                let layer = try #require(panel.contentView?.layer)
                #expect(switcher.isVisible && screen.presentations == 1)
                #expect(layer.animation(forKey: ThemeSwitcher.summonKey) != nil)

                let enter = try #require(
                    NSEvent.keyEvent(
                        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                        windowNumber: panel.windowNumber, context: nil, characters: "\r",
                        charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
                #expect(!panel.drops(enter))
                switcher.close()
                #expect(panel.isDismissing && panel.drops(enter))
                // A second close while fading changes nothing.
                switcher.close()

                // Opening mid-fade finishes the close rather than waiting for it.
                await switcher.show()
                #expect(screen.dismissals == 1 && screen.presentations == 2)
                #expect(switcher.isVisible && !panel.isDismissing && !panel.drops(enter))
                try await waitUntil("the panel faded in") { panel.alphaValue == 1 }

                // Under Reduce Motion it only fades.
                switcher.reduceMotion = { true }
                switcher.close()
                try await waitUntil("the fade to close the panel") { !switcher.isVisible }
                #expect(screen.dismissals == 2 && !panel.isDismissing && panel.alphaValue == 1)
                await switcher.show()
                #expect(screen.presentations == 3)
                #expect(layer.animation(forKey: ThemeSwitcher.summonKey) == nil)
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("counts, the palette sample and the empty list read well")
        func readable() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "1-office.png", red: 0.1)
                harness.model.themes.reload()
                let (switcher, surface) = try harness.switcherPage(recorder: ThemeRecorder())
                defer { withExtendedLifetime(switcher) {} }
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")
                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                try await waitFor(
                    surface, "singular counts, read in full",
                    """
                    const [backgrounds] = page.rows();
                    const lumon = page.activeRow();
                    const short = [...lumon.querySelectorAll("[aria-hidden=true]")]
                      .find((span) => span.textContent === "1 bg");
                    return backgrounds.innerText.includes("1 option")
                      && !!short && lumon.textContent.includes("1 background");
                    """)
                try await waitFor(
                    surface, "the palette sample hidden from VoiceOver",
                    """
                    return [...document.querySelectorAll("[aria-hidden=true]")]
                      .some((element) => element.textContent.startsWith("ls -la"));
                    """)
                try await run(surface, #"page.setValue(page.search(), "zzz");"#)
                try await waitFor(
                    surface, "the empty message over the list, not the preview",
                    """
                    const list = document.querySelector('[role=listbox][aria-label="Themes"]');
                    const message = [...list.parentElement.children]
                      .find((child) => child.textContent === "No matching themes");
                    return page.rows().length === 0 && !!message
                      && message.getBoundingClientRect().right <= list.getBoundingClientRect().right;
                    """)
            }
        }

        @Test("the preview keeps the last wallpaper until the next has loaded")
        func keepsWallpaper() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "1-office.png", red: 0.1)
                try harness.addBackground(theme: "carbonfox", name: "1-ember.png", red: 0.5)
                harness.model.themes.reload()
                let (switcher, surface) = try harness.switcherPage(recorder: ThemeRecorder())
                defer { withExtendedLifetime(switcher) {} }
                try await waitFor(surface, "the theme list", "return page.rows().length === 9;")
                await surface.deliver(.switcherWillOpen(harness.model.switcherState()))
                let wallpapers = "[...document.querySelectorAll('.aspect-video img')]"
                try await waitFor(
                    surface, "the Lumon wallpaper",
                    "return \(wallpapers).some((img) => img.src.includes('/theme/lumon/'));")

                try await run(surface, #"page.setValue(page.search(), "carbon");"#)
                try await waitFor(
                    surface, "Carbonfox's wallpaper loaded over Lumon's",
                    """
                    const images = \(wallpapers);
                    const top = images.at(-1);
                    return images.length === 2 && images[0].src.includes("/theme/lumon/")
                      && top.src.includes("/theme/carbonfox/") && top.complete
                      && !top.classList.contains("opacity-0");
                    """)

                try await run(surface, #"page.setValue(page.search(), "midnight");"#)
                try await waitFor(
                    surface, "no wallpaper for a theme without one",
                    """
                    return \(wallpapers).length === 0
                      && page.text().includes("No wallpaper in this theme");
                    """)
            }
        }
    }
}
