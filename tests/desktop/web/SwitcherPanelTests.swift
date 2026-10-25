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
    }
}
