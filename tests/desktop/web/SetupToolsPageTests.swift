import Foundation
import Testing

@testable import App
@testable import Macarchy

/// Homebrew in place of the real one: installing puts an executable for the
/// formula's last part in `bin`, printing one line; removing deletes it, and
/// trusting a tap does nothing.
func fakeHomebrew(_ bin: URL) -> ToolInstaller.Run {
    { _, arguments, line in
        let name = arguments.last.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        let file = bin.appending(path: name)
        if arguments.first == "install" {
            line("==> Pouring \(name)")
            try? Data("#!/bin/sh\nexit 1\n".utf8).write(to: file)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: file.path)
        } else if arguments.first == "uninstall" {
            try? FileManager.default.removeItem(at: file)
        }
        return CommandResult(command: "brew " + arguments.joined(separator: " "), status: 0)
    }
}

/// The scripts the page asked to open in Terminal.
@MainActor
final class TerminalRecorder {
    var opened: [URL] = []
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Setup page tools")
    struct SetupToolsPageTests {
        private func useFakeHomebrew(_ harness: Harness) {
            harness.model.setupSession = SetupSession(
                integrations: harness.model.backend,
                applyTheme: { CommandResult(command: "record theme \($0)", status: 0) },
                installer: ToolInstaller(run: fakeHomebrew(harness.bin)))
        }

        @Test("unticked tools are left alone and missing ones install with their output shown")
        func chooseAndInstall() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: ["yabai", "brew"]) { harness in
                try await withSetupResources(harness) {
                    useFakeHomebrew(harness)
                    try FileManager.default.removeItem(at: harness.store.url)
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "tools to choose",
                        """
                        const text = page.text();
                        return text.includes("Choose your tools") && text.includes("bordersrc")
                          && [...document.querySelectorAll('button')].some(b => b.textContent === "Install and set up");
                        """)
                    try await run(
                        surface,
                        #"document.querySelector('[aria-label="Set up borders"]').click();"#)
                    try await waitFor(
                        surface, "plan without borders",
                        """
                        return document.querySelector('[aria-label="Set up borders"]').getAttribute('aria-checked') === "false"
                          && !page.text().includes("bordersrc");
                        """)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Install and set up").click();"#
                    )
                    try await waitFor(
                        surface, "setup results with Homebrew's output",
                        """
                        const text = page.text();
                        return text.includes("What setup did")
                          && text.includes("Installed skhd with Homebrew")
                          && text.includes("Installed SketchyBar with Homebrew")
                          && text.includes("==> Pouring sketchybar");
                        """)
                    #expect(try harness.store.read().tools == ["yabai", "sketchybar", "skhd"])
                    #expect(
                        !FileManager.default.fileExists(
                            atPath: StartupConfiguration.bordersrc.url.path))
                    #expect(!Paths.isInstalled("borders"))
                    #expect(
                        Set(harness.model.setupSession.installer.removable().map(\.id))
                            == ["skhd", "sketchybar"])
                }
            }
        }

        @Test("own configs offer a choice per tool, and starting skhd fresh is kept apart")
        func perToolChoice() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: ["yabai", "skhd"]) { harness in
                try await withSetupResources(harness) {
                    try FileManager.default.removeItem(at: harness.store.url)
                    try harness.write(
                        "yabai -m config window_gap 17\n", to: ".config/yabai/yabairc")
                    try harness.write("cmd - h : echo mine\n", to: ".config/skhd/skhdrc")
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "a choice for each own config",
                        #"return document.querySelectorAll('[role=radiogroup]').length === 2;"#)
                    try await run(
                        surface,
                        #"[...document.querySelector('[aria-label="How skhd starts"]').querySelectorAll('label')].find(e => e.textContent.includes("Use Macarchy's defaults")).click();"#
                    )
                    try await waitFor(
                        surface, "skhd from defaults",
                        #"return page.text().includes("Installs Macarchy's default shortcuts");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Set up Macarchy").click();"#
                    )
                    try await waitFor(
                        surface, "results", #"return page.text().includes("What setup did");"#)
                    #expect(try harness.store.read().flatValues["YABAI_WINDOW_GAP"] == "17")
                    #expect(
                        try !String(contentsOf: Setup.skhdrc, encoding: .utf8).contains(
                            "echo mine"))
                }
            }
        }

        @Test("without Homebrew the page opens its installer in Terminal, then checks again")
        func homebrewMissing() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: ["yabai"]) { harness in
                try await withSetupResources(harness) {
                    let terminal = TerminalRecorder()
                    harness.model.openInTerminal = { script in
                        terminal.opened.append(script)
                        return nil
                    }
                    try FileManager.default.removeItem(at: harness.store.url)
                    let (_, surface) = try harness.settingsPage()
                    try await waitFor(
                        surface, "Homebrew's installer offered",
                        """
                        return page.text().includes("Homebrew is not installed yet")
                          && [...document.querySelectorAll('button')].some(b => b.textContent === "Set up Macarchy");
                        """)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Install Homebrew in Terminal").click();"#
                    )
                    try await waitUntil("Terminal opened") { !terminal.opened.isEmpty }
                    #expect(terminal.opened.first?.pathExtension == "command")
                    try harness.install("brew")
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('button')].find(b => b.textContent === "Check again").click();"#
                    )
                    try await waitFor(
                        surface, "installing offered once Homebrew is there",
                        """
                        return !page.text().includes("Homebrew is not installed yet")
                          && [...document.querySelectorAll('button')].some(b => b.textContent === "Install and set up");
                        """)
                }
            }
        }

        @Test("restoring offers the tools Macarchy installed, unticked, and removes those ticked")
        func restoreRemovesTicked() async throws {
            defer { InterfacePreferences.selectedPane = .layout }
            try await withHarness(tools: ["yabai", "brew"]) { harness in
                try await withSetupResources(harness) {
                    useFakeHomebrew(harness)
                    _ = await harness.model.setupSession.run(
                        Setup.Choices(tools: [.yabai, .skhd, .borders]), app: nil, install: true)
                    #expect(Paths.isInstalled("skhd") && Paths.isInstalled("borders"))
                    let (_, surface) = try harness.settingsPage(pane: .advanced)
                    try await waitFor(
                        surface, "restore originals",
                        #"return page.text().includes("Restore original files");"#)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('[data-slot=row]')].find(e => e.textContent.includes('Restore original files')).querySelector('button').click();"#
                    )
                    try await waitFor(
                        surface, "tools offered unticked",
                        """
                        const boxes = [...document.querySelectorAll('[role=alertdialog] [role=checkbox]')];
                        return boxes.length === 2 && boxes.every(b => b.getAttribute('aria-checked') === "false")
                          && !document.querySelector('[role=alertdialog]').textContent.includes("yabai");
                        """)
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('[role=alertdialog] label')].find(l => l.textContent.includes("skhd")).querySelector('[role=checkbox]').click();"#
                    )
                    try await waitFor(
                        surface, "skhd ticked",
                        #"return [...document.querySelectorAll('[role=alertdialog] [role=checkbox]')].some(b => b.getAttribute('aria-checked') === "true");"#
                    )
                    try await run(
                        surface,
                        #"[...document.querySelectorAll('[role=alertdialog] button')].find(b => b.textContent === 'Restore').click();"#
                    )
                    try await waitUntil("skhd removed") { !Paths.isInstalled("skhd") }
                    try await waitFor(
                        surface, "the report",
                        #"return page.text().includes("Removed skhd with Homebrew");"#)
                    #expect(Paths.isInstalled("borders"))
                    #expect(Paths.isInstalled("yabai"))
                }
            }
        }
    }
}
