import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
func withSetupResources(_ harness: Harness, _ body: () async throws -> Void) async throws {
    let previous = getenv("MACARCHY_RESOURCES").map { String(cString: $0) }
    let resources = harness.home.appending(path: "resources")
    let fm = FileManager.default
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)
    try fm.copyItem(
        at: repository.appending(path: "resources/themes"), to: resources.appending(path: "themes"))
    try fm.copyItem(
        at: repository.appending(path: "resources/integrations/skhd"),
        to: resources.appending(path: "skhd"))
    setenv("MACARCHY_RESOURCES", resources.path, 1)
    defer {
        if let previous {
            setenv("MACARCHY_RESOURCES", previous, 1)
        } else {
            unsetenv("MACARCHY_RESOURCES")
        }
    }
    harness.model.setupSession = SetupSession(
        integrations: harness.model.backend,
        applyTheme: { name in
            CommandResult(command: "record theme \(name)", status: 0, stdout: "Theme recorded")
        })
    try await body()
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Setup page")
    struct SetupPageTests {
        @Test("setup failure stays visible and does not pretend that settings were saved")
        func setupFailure() async throws {
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.removeItem(at: harness.store.url)
                    try FileManager.default.removeItem(
                        at: harness.home.appending(path: "resources/themes"))
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "setup plan", #"return page.text().includes("What will change");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Set up Macarchy").click();"#
                    )
                    try await waitFor(
                        surface, "setup error",
                        #"return page.text().includes("Setup could not finish") && page.text().includes("some files may already have changed");"#
                    )
                    #expect(!FileManager.default.fileExists(atPath: harness.store.url.path))
                }
            }
        }

        @Test("a partial setup shows the completed lines and the error together until Done")
        func partialFailure() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.removeItem(at: harness.store.url)
                    try FileManager.default.createDirectory(
                        at: StartupConfiguration.sketchybarrc.url,
                        withIntermediateDirectories: true)
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "setup plan", #"return page.text().includes("What will change");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Set up Macarchy").click();"#
                    )
                    try await waitFor(
                        surface, "partial results",
                        """
                        const text = page.text();
                        return text.includes("Setup could not finish")
                          && text.includes("some files may already have changed")
                          && text.includes("What setup did")
                          && text.includes("Installed default shortcuts")
                          && [...document.querySelectorAll('button')].some(b => b.textContent === "Done");
                        """)
                }
            }
        }

        @Test(
            "first run shows a read-only plan in React, then keep mine runs safely and retains results"
        )
        func firstRun() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.removeItem(at: harness.store.url)
                    try harness.write(
                        "yabai -m config window_gap 17\necho mine\n", to: ".config/yabai/yabairc")
                    let original = try String(
                        contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "setup plan",
                        #"return page.text().includes("What will change") && page.text().includes("Keep mine and add Macarchy");"#
                    )
                    #expect(!FileManager.default.fileExists(atPath: harness.store.url.path))
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            == original)
                    #expect(await harness.desktop.calls.isEmpty)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Set up Macarchy").click();"#
                    )
                    try await waitFor(
                        surface, "setup results",
                        #"return page.text().includes("What setup did") && page.text().includes("Theme recorded");"#
                    )
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            .contains("echo mine"))
                    #expect(!harness.model.shellState().setupRequired)
                }
            }
        }

        @Test("start fresh previews replacement and saves defaults instead of adopted values")
        func startFresh() async throws {
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.removeItem(at: harness.store.url)
                    try harness.write(
                        "yabai -m config window_gap 29\n", to: ".config/yabai/yabairc")
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "existing setup choices",
                        #"return !!document.querySelector('[role=radio][value=replace]') || page.text().includes("Start fresh with Macarchy's defaults");"#
                    )
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('label')].find(e => e.textContent.includes("Start fresh with Macarchy's defaults")).click();"#
                    )
                    try await waitFor(
                        surface, "replacement plan",
                        #"return page.text().includes("Replaced; the original is backed up");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Set up Macarchy").click();"#
                    )
                    try await waitFor(
                        surface, "fresh setup results",
                        #"return page.text().includes("What setup did");"#)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] != "29")
                }
            }
        }

        @Test("restore originals requires confirmation and uses the injected backend")
        func originals() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: []) { harness in
                try await withSetupResources(harness) {
                    let original = "echo original\n"
                    try harness.write(original, to: ".config/yabai/yabairc")
                    _ = await harness.model.setupSession.run(existing: .replace, app: nil)
                    let (_, surface) = try harness.settingsPage(pane: .advanced)
                    try await waitFor(
                        surface, "restore originals",
                        #"return page.text().includes("Restore original files");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('[data-slot=row]')].find(e => e.textContent.includes('Restore original files')).querySelector('button').click();"#
                    )
                    try await waitFor(
                        surface, "confirmation", #"return page.text().includes("Really restore?");"#
                    )
                    #expect(
                        try String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8)
                            != original)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('[role=alertdialog] button')].find(b => b.textContent === 'Restore').click();"#
                    )
                    try await waitUntil("original restored") {
                        (try? String(contentsOf: StartupConfiguration.yabairc.url, encoding: .utf8))
                            == original
                    }
                }
            }
        }
    }
}
