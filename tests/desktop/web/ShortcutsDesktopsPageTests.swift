import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Shortcuts page desktops")
    struct ShortcutsDesktopsPageTests {
        @Test("desktop bindings fold, and those for desktops yabai does not list are dimmed")
        func desktops() async throws {
            let numbered = (1...9).map { "ctrl + alt - \($0) : yabai -m space --focus \($0)\n" }
            try await withHarness { harness in
                try harness.write(numbered.joined(), to: ".config/skhd/skhdrc")
                let spaces = "[" + Array(repeating: "{}", count: 3).joined(separator: ",") + "]"
                await harness.desktop.answer(
                    "yabai", ["-m", "query", "--spaces"], with: .success(spaces))
                #expect(try await harness.model.readShortcuts().desktops == 3)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitFor(
                    surface, "one folded row for the nine bindings",
                    #"return !!document.querySelector('[aria-label^="Show 9 shortcuts: Go to desktop 1–9"]') && !document.querySelector('[data-shortcut-id]');"#
                )
                try await run(
                    surface,
                    #"document.querySelector('[aria-label^="Show 9 shortcuts: Go to desktop 1–9"]').click();"#
                )
                try await waitFor(
                    surface, "the nine rows, with desktops 4 to 9 marked",
                    #"return document.querySelectorAll('[data-shortcut-id]').length === 9 && document.querySelectorAll('[data-missing-desktop]').length === 6 && page.text().includes('No desktop 4 yet') && !page.text().includes('No desktop 3 yet');"#
                )
                await harness.desktop.stop()
                #expect(try await harness.model.readShortcuts().desktops == nil)
            }
        }
    }
}
