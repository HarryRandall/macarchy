import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Shortcuts page enabling")
    struct ShortcutsEnablePageTests {
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
