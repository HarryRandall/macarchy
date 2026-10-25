import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Uses the parent's isolated environment; the page test makes a web view.
    @MainActor
    @Suite("Uninstalling and Advanced after cleaning up")
    struct OldConfigurationAppTests {
        @Test("uninstalling after a cleanup puts the moved scripts and old files back")
        func uninstallsAfterCleanup() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                let fm = FileManager.default
                let yabai = harness.home.appending(path: ".config/yabai")
                let launch = try String(
                    contentsOf: yabai.appending(path: "launch.sh"), encoding: .utf8)
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                #expect(report.failure == nil, "\(report.lines)")
                // Edited after cleaning up, so uninstall keeps this copy too.
                try harness.write(
                    "#!/bin/bash\necho edited\n",
                    to: "Library/Application Support/Macarchy/scripts/mine.sh")
                _ = try await Setup.uninstall(integrations: harness.model.backend)
                #expect(
                    try String(contentsOf: yabai.appending(path: "launch.sh"), encoding: .utf8)
                        == launch)
                #expect(fm.isExecutableFile(atPath: yabai.appending(path: "launch.sh").path))
                #expect(
                    try fm.attributesOfItem(atPath: yabai.appending(path: "state.json").path)[
                        .posixPermissions] as? Int == 0o600)
                #expect(fm.fileExists(atPath: yabai.appending(path: "mine.sh").path))
                #expect(
                    fm.fileExists(atPath: harness.home.appending(path: ".config/skhd/skhdrc").path))
                #expect(!fm.fileExists(atPath: yabai.appending(path: "macarchy-yabairc").path))
                #expect(!fm.fileExists(atPath: Paths.launcherDirectory.path))
                #expect(
                    try fm.contentsOfDirectory(atPath: Paths.scriptsDirectory.path) == ["mine.sh"])
            }
        }

        @Test("Advanced reviews the plan, asks first and reports what was done")
        func advancedPage() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness { harness in
                try upgradedHome(harness)
                let before = cleanupTree(harness)
                let surface = try harness.settingsPage(pane: .advanced).1
                try await waitFor(
                    surface, "cleanup card",
                    #"return page.text().includes("Clean up old configuration");"#)
                try await run(
                    surface,
                    #"[...document.querySelectorAll('button')].find(b => b.textContent === "Review").click();"#
                )
                try await waitFor(
                    surface, "plan",
                    #"return document.querySelector('[role=alertdialog]')?.textContent.includes("~/.config/yabai/launch.sh");"#
                )
                #expect(cleanupTree(harness) == before)
                try await run(
                    surface,
                    #"[...document.querySelectorAll('[role=alertdialog] button')].find(b => b.textContent === "Clean up").click();"#
                )
                try await waitFor(
                    surface, "report",
                    #"return page.text().includes("Old configuration cleaned up") && page.text().includes("Moved ~/.config/yabai/launch.sh");"#
                )
                #expect(
                    FileManager.default.fileExists(
                        atPath: Paths.scriptsDirectory.appending(path: "launch.sh").path))
                #expect(!OldConfiguration.archives.isEmpty)
            }
        }
    }
}
