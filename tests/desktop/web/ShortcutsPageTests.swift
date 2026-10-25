import Foundation
import Testing

@testable import App
@testable import Macarchy

private let shortcutsFixture = """
    # Launch terminal
    ctrl - return : echo terminal

    # Focus windows
    ctrl - h : yabai -m window --focus west
    ctrl - l : yabai -m window --focus east

    # Per-app action
    alt - p -> [
      "Finder" : echo finder
      * : echo other
    ]

    """

@MainActor
private func waitForShortcuts(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "Shortcuts from the isolated skhdrc",
        """
        return !!document.querySelector('[data-shortcut-id="1"]')
          && page.text().includes("4 shortcuts") && page.text().includes("Launch terminal");
        """)
}

@MainActor
private func shortcutClick(_ surface: WebSurface, _ title: String) async throws {
    try await run(
        surface,
        """
        const button = [...document.querySelectorAll('button, [role=menuitem]')]
          .find((element) => element.textContent.trim() === "\(title)"
            || element.getAttribute('aria-label') === "\(title)");
        if (!button) throw new Error("Missing button: \(title)");
        button.click();
        """)
}

@MainActor
private func editFirstShortcut(_ surface: WebSurface) async throws {
    try await run(
        surface,
        #"document.querySelector('[data-shortcut-id="1"] button[aria-label^="Edit shortcut"]').click();"#
    )
    try await waitFor(
        surface, "the shortcut editor",
        #"return !!document.querySelector('[role=dialog]') && page.text().includes('Edit shortcut');"#
    )
}

@MainActor
private func recordShortcut(_ surface: WebSurface, code: String = "KeyK") async throws {
    try await run(
        surface,
        """
        const recorder = document.querySelector('[aria-label="Record key combination"]');
        recorder.focus(); recorder.click();
        """)
    // The click starts recording in React's next commit, as it would before
    // a person's next key press; a key sent in the same script would be early.
    try await waitFor(
        surface, "the recorder to listen",
        #"return document.querySelector('[aria-label="Record key combination"]').getAttribute('aria-pressed') === 'true';"#
    )
    try await run(
        surface,
        """
        const recorder = document.querySelector('[aria-label="Record key combination"]');
        page.key(recorder, "k", {code: "\(code)", metaKey: true});
        """)
    try await waitFor(
        surface, "Swift to validate the recording", #"return page.text().includes('cmd - k');"#)
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Shortcuts page")
    struct ShortcutsPageTests {
        @Test("opening and refreshing read real skhdrc without writing or restarting")
        func openingIsReadOnly() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let before = harness.settingsData
                let snapshotsBefore = SnapshotStore().list().count
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                try await shortcutClick(surface, "Shortcut actions")
                try await shortcutClick(surface, "Refresh shortcuts")
                try await waitForShortcuts(surface)
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == shortcutsFixture)
                #expect(harness.settingsData == before)
                #expect(await harness.desktop.calls(to: "launchctl").isEmpty)
                #expect(SnapshotStore().list().count == snapshotsBefore)
            }
        }

        @Test("the top bar's search filters the bindings read from skhdrc")
        func pageSearch() async throws {
            try await withHarness { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                try await run(
                    surface,
                    #"page.setValue(document.querySelector('input[aria-label="Search shortcuts"]'), 'focus');"#
                )
                try await waitFor(
                    surface, "the two focus bindings",
                    #"return document.querySelectorAll('[data-shortcut-id]').length === 2 && page.text().includes('2 of 4 shortcuts');"#
                )
                try await shortcutClick(surface, "Clear search")
                try await waitForShortcuts(surface)
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == shortcutsFixture)
            }
        }

        @Test("recording reaches Swift, saves only the chord, snapshots and restarts skhd")
        func rebind() async throws {
            try await withHarness(tools: ["skhd"]) { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                await harness.desktop.answer("launchctl") { arguments in
                    arguments.first == "print"
                        ? .success("state = running\npid = 123\n") : .success()
                }
                let before = harness.settingsData
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                try await editFirstShortcut(surface)
                try await recordShortcut(surface)
                try await shortcutClick(surface, "Save")
                try await waitUntil("the rebound chord in skhdrc") {
                    (try? SkhdShortcuts().read().bindings.first?.key) == "k"
                }
                try await waitFor(
                    surface, "the saved editor to close",
                    #"return !document.querySelector('[role=dialog]');"#)
                #expect(
                    try String(contentsOf: Setup.skhdrc, encoding: .utf8)
                        == shortcutsFixture.replacingOccurrences(
                            of: "ctrl - return", with: "cmd - k"))
                #expect(harness.settingsData == before)
                #expect(
                    await harness.desktop.calls(to: "launchctl").contains {
                        $0.first == "kickstart"
                    })
                #expect(
                    SnapshotStore().list().contains {
                        SnapshotStore().reason(for: $0) == "shortcut rebind"
                    })
            }
        }

        @Test("native Command keys are captured before shell search")
        func commandRecording() async throws {
            try await withHarness { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let (window, surface) = try offscreenSettings(harness, pane: .shortcuts)
                defer { window.contentView = nil }
                try await waitForShortcuts(surface)
                try await editFirstShortcut(surface)
                try await run(
                    surface,
                    #"const recorder = document.querySelector('[aria-label="Record key combination"]'); recorder.focus(); recorder.click();"#
                )
                try press(.command("k"), in: window)
                try await waitFor(
                    surface, "the native Command K recording",
                    #"return page.text().includes('cmd - k');"#)
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == shortcutsFixture)
            }
        }

        @Test("conflicts and externally changed files leave the configuration unchanged")
        func staleAndConflict() async throws {
            try await withHarness { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                try await editFirstShortcut(surface)
                try await run(
                    surface,
                    #"const recorder = document.querySelector('[aria-label="Record key combination"]'); recorder.focus(); recorder.click();"#
                )
                try await waitFor(
                    surface, "the recorder to listen",
                    #"return document.querySelector('[aria-label="Record key combination"]').getAttribute('aria-pressed') === 'true';"#
                )
                try await run(
                    surface,
                    #"page.key(document.querySelector('[aria-label="Record key combination"]'), 'h', {code: 'KeyH', ctrlKey: true});"#
                )
                try await waitFor(
                    surface, "the conflict warning",
                    #"return page.text().includes('Already used by Focus windows');"#)
                try await recordShortcut(surface)
                let external = shortcutsFixture + "# edited outside Macarchy\n"
                try harness.write(external, to: shortcutsFile)
                try await shortcutClick(surface, "Save")
                try await waitFor(
                    surface, "the stale file failure",
                    #"return page.text().includes('skhdrc changed since it was read');"#)
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == external)
            }
        }

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

        @Test("external changes arrive through the broadcaster without clobbering the recording")
        func externalChanges() async throws {
            try await withHarness { harness in
                try harness.write(shortcutsFixture, to: shortcutsFile)
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitForShortcuts(surface)
                let broadcast = ShortcutsBroadcast()
                broadcast.written(try harness.model.readShortcuts())
                broadcast.start { [weak surface] in surface?.send($0) }
                try await editFirstShortcut(surface)
                try await recordShortcut(surface)
                try harness.write(
                    shortcutsFixture + "cmd - q : echo external\n", to: shortcutsFile)
                try await waitFor(
                    surface, "external edits and the preserved recording",
                    #"return page.text().includes('5 shortcuts') && page.text().includes('Your recording has been kept') && page.text().includes('cmd - k');"#
                )
                try await shortcutClick(surface, "Cancel")
                try await waitFor(
                    surface, "the externally added shortcut",
                    #"return document.querySelectorAll('[data-shortcut-id]').length === 5;"#)
                withExtendedLifetime(broadcast) {}
            }
        }

        @Test("missing configuration shows Try again; confirmed reset uses bundled defaults")
        func missingAndReset() async throws {
            try await withHarness { harness in
                let (_, surface) = try harness.settingsPage(pane: .shortcuts)
                try await waitFor(
                    surface, "the read failure",
                    #"return page.text().includes('Could not read your shortcuts') && page.text().includes('Try again');"#
                )
                #expect(!FileManager.default.fileExists(atPath: Setup.skhdrc.path))
                try harness.write(shortcutsFixture, to: shortcutsFile)
                try await shortcutClick(surface, "Try again")
                try await waitForShortcuts(surface)
                let previous = getenv("MACARCHY_RESOURCES").map { String(cString: $0) }
                setenv("MACARCHY_RESOURCES", harness.home.appending(path: "resources").path, 1)
                defer {
                    if let previous {
                        setenv("MACARCHY_RESOURCES", previous, 1)
                    } else {
                        unsetenv("MACARCHY_RESOURCES")
                    }
                }
                try harness.write("cmd - t : echo default\n", to: "resources/skhd/skhdrc")
                try await shortcutClick(surface, "Shortcut actions")
                try await shortcutClick(surface, "Reset to default shortcuts…")
                try await waitFor(
                    surface, "reset confirmation",
                    #"return page.text().includes('Reset to default shortcuts?');"#)
                #expect(try String(contentsOf: Setup.skhdrc, encoding: .utf8) == shortcutsFixture)
                try await shortcutClick(surface, "Reset")
                try await waitUntil("the confirmed defaults") {
                    (try? SkhdShortcuts().read().bindings.first?.command) == "echo default"
                }
                #expect(
                    SnapshotStore().list().contains {
                        SnapshotStore().reason(for: $0) == "reset shortcuts"
                    })
            }
        }
    }
}
