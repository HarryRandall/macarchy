import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Uses the parent's isolated environment without creating a web view.
    @MainActor
    @Suite("Restoring after edits and moved folders")
    struct OldConfigurationRestoreTests {
        @Test("restoring keeps a file edited since cleaning up and puts the old one beside it")
        func keepsEditedFiles() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                let zshrc = harness.home.appending(path: ".zshrc")
                let original = try String(contentsOf: zshrc, encoding: .utf8)
                let shortcuts = try String(contentsOf: Paths.skhdrc, encoding: .utf8)
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                #expect(report.failure == nil, "\(report.lines)")
                let archive = try #require(report.archive)
                let edited = try String(contentsOf: zshrc, encoding: .utf8) + "alias ll='ls -l'\n"
                try harness.write(edited, to: ".zshrc")

                let restored = await OldConfiguration.restore(
                    archive.lastPathComponent, integrations: harness.model.backend)
                #expect(restored.failure == nil, "\(restored.lines)")
                #expect(try String(contentsOf: zshrc, encoding: .utf8) == edited)
                let beside = harness.home.appending(path: ".zshrc.before-cleanup")
                #expect(try String(contentsOf: beside, encoding: .utf8) == original)
                #expect(
                    restored.lines.contains(
                        "Kept ~/.zshrc, which changed after cleaning up; the version from before "
                            + "cleaning up is in ~/.zshrc.before-cleanup"))
                #expect(try String(contentsOf: Paths.skhdrc, encoding: .utf8) == shortcuts)
            }
        }

        @Test("a moved folder nobody edited leaves the scripts folder on restore")
        func movedFolders() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                let fm = FileManager.default
                try harness.write(
                    "#!/bin/bash\ncat \"$HOME/.config/yabai/state.json\"\n",
                    to: ".config/yabai/lib/read.sh")
                try harness.write("notes\n", to: ".config/yabai/lib/notes.txt")
                let before = cleanupTree(harness)
                let plan = await OldConfiguration.plan()
                #expect(plan.moves.contains { $0.from.lastPathComponent == "lib" })
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                #expect(report.failure == nil, "\(report.lines)")
                let lib = Paths.scriptsDirectory.appending(path: "lib")
                #expect(
                    try String(contentsOf: lib.appending(path: "read.sh"), encoding: .utf8)
                        .contains("Macarchy/scripts/state.json"))
                // Finder's settings do not count as an edit.
                try harness.write(
                    "", to: "Library/Application Support/Macarchy/scripts/lib/.DS_Store")

                let restored = await OldConfiguration.restore(
                    try #require(report.archive).lastPathComponent,
                    integrations: harness.model.backend)
                #expect(restored.failure == nil, "\(restored.lines)")
                #expect(!fm.fileExists(atPath: lib.path), "\(restored.lines)")
                #expect(!restored.lines.contains { $0.contains("changed after cleaning up") })
                #expect(!fm.fileExists(atPath: Paths.scriptsDirectory.path))
                #expect(cleanupTree(harness) == before)
            }
        }

        @Test("a moved folder edited since stays beside the original")
        func editedMovedFolder() async throws {
            try await withHarness { harness in
                try upgradedHome(harness)
                try harness.write("notes\n", to: ".config/yabai/lib/notes.txt")
                let report = await OldConfiguration.apply(integrations: harness.model.backend)
                try harness.write(
                    "more\n", to: "Library/Application Support/Macarchy/scripts/lib/new.txt")
                let restored = await OldConfiguration.restore(
                    try #require(report.archive).lastPathComponent,
                    integrations: harness.model.backend)
                #expect(restored.failure == nil, "\(restored.lines)")
                #expect(
                    restored.lines.contains(
                        "Left ~/Library/Application Support/Macarchy/scripts/lib, which changed "
                            + "after cleaning up; it is now beside the original"))
                #expect(
                    FileManager.default.fileExists(
                        atPath: harness.home.appending(path: ".config/yabai/lib/notes.txt").path))
            }
        }
    }
}
