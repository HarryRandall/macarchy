import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Shortcuts page disabling and enabling")
    struct ShortcutsEnablePageTests {
        @Test("disable keeps the block as comments, Enable restores it, and failed reloads show")
        func disableAndReloadFailure() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                try await run(
                    surface,
                    #"document.querySelector('[data-shortcut-id="8"] button[aria-label^="Edit shortcut"]').click();"#
                )
                try await waitFor(
                    surface, "the per-app editor", #"return page.text().includes('Edit shortcut');"#
                )
                try await shortcutClick(surface, "Disable")
                #expect(try SkhdShortcuts().read().bindings.count == 4)
                try await shortcutClick(surface, "Really disable?")
                try await waitFor(
                    surface, "the partial application warning",
                    #"return page.text().includes('Shortcuts were saved, but skhd could not restart');"#
                )
                #expect(try SkhdShortcuts().read().bindings.count { !$0.isDisabled } == 3)
                #expect(
                    try String(contentsOf: Setup.skhdrc, encoding: .utf8).contains(
                        "#   \"Finder\" : echo finder"))
                try await waitFor(
                    surface, "the disabled row with Enable",
                    #"return page.text().includes('4 shortcuts, 1 disabled') && !!document.querySelector('[data-shortcut-id="8"] button[aria-label^="Enable shortcut"]');"#
                )
                try await shortcutClick(surface, "Enable")
                try await waitUntil("the enabled block in skhdrc") {
                    (try? String(contentsOf: Setup.skhdrc, encoding: .utf8)) == shortcutsFixture
                }
                #expect(
                    SnapshotStore().list().contains {
                        SnapshotStore().reason(for: $0) == "shortcut enabled"
                    })
            }
        }

        @Test("Enable refuses a chord another shortcut took and shows why")
        func enableClash() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                let fixture = """
                    # Focus left
                    # disabled: ctrl - h : yabai -m window --focus west

                    # Open notes
                    ctrl - h : open -a Notes

                    """
                try harness.write(fixture, to: shortcutsFile)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitFor(
                    surface, "the disabled shortcut",
                    #"return !!document.querySelector('[data-shortcut-id="1"] button[aria-label^="Enable shortcut"]');"#
                )
                try await run(
                    surface,
                    #"document.querySelector('[data-shortcut-id="1"] button[aria-label^="Enable shortcut"]').click();"#
                )
                try await waitFor(
                    surface, "the clash error",
                    #"return document.querySelector('[role=alert]')?.innerText.includes('is now used by "Open notes"');"#
                )
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == fixture)
                #expect(
                    !SnapshotStore().list().contains {
                        SnapshotStore().reason(for: $0) == "shortcut enabled"
                    })
            }
        }
    }
}
