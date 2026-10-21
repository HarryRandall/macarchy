import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
private func themesPage(
    _ harness: Harness, actions: ThemeActions, panels: ThemePanels? = nil
) throws -> WebSurface {
    let (_, surface) = try harness.settingsPage(pane: .themes)
    surface.router.registerThemes(
        model: harness.model, actions: actions,
        panels: panels
            ?? ThemePanels(importFolder: { nil }, exportFolder: { _ in nil }, reveal: { _ in }))
    surface.load()
    return surface
}

@MainActor
private func waitForThemes(_ surface: WebSurface) async throws {
    try await waitFor(
        surface, "the Themes collection",
        "return !!document.querySelector('[aria-label^=\"View lumon\" i]');")
}

@MainActor
private func waitForCurrent(_ surface: WebSurface, _ theme: String) async throws {
    try await waitFor(
        surface, "the current theme",
        "return !!document.querySelector('[data-theme=\"\(theme)\"][data-current]');")
}

@MainActor
private func themeButton(_ surface: WebSurface, _ label: String) async throws {
    try await run(
        surface,
        "[...document.querySelectorAll('button')].find(b => b.textContent.trim() === '\(label)').click();"
    )
}

@MainActor
private func chooseWallpaper(_ surface: WebSurface, _ path: String) async throws {
    try await waitFor(
        surface, "the wallpaper strip",
        "return !!document.querySelector('[data-wallpaper=\"\(path)\"]:not(:disabled)');")
    try await run(surface, "document.querySelector('[data-wallpaper=\"\(path)\"]').click();")
}

@MainActor
private func editThemeColours(_ surface: WebSurface) async throws {
    for label in [
        "Border active", "Border inactive", "Menu bar background", "Menu bar text",
        "Firefox accent"
    ] {
        try await run(
            surface,
            "document.querySelector('button[data-slot=colour-well][aria-label^=\"\(label),\"]').click();"
        )
        try await waitFor(
            surface, "the colour picker",
            "return !!document.querySelector('input[aria-label=\"\(label) hex value\"]');"
        )
        try await run(
            surface,
            "const input = document.querySelector('input[aria-label=\"\(label) hex value\"]'); page.setValue(input, '#123456'); page.key(input, 'Enter');"
        )
        try await waitFor(
            surface, "the saved colour",
            "return document.querySelector('button[data-slot=colour-well][aria-label^=\"\(label),\"]').textContent.includes('123456');"
        )
        try await run(
            surface,
            "page.key(document.querySelector('input[aria-label=\"\(label) hex value\"]'), 'Escape');"
        )
    }
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Themes page", ThemeResources())
    struct ThemesPageTests {
        @Test(
            "opening and refreshing real theme state writes nothing and external changes refresh the page"
        )
        func readOnlyAndExternalChange() async throws {
            try await withHarness { harness in
                let recorder = ThemeRecorder()
                let before = harness.settingsData
                let directory = harness.themes.appending(path: "lumon")
                let manifest = try Data(contentsOf: directory.appending(path: "theme.json"))
                let surface = try themesPage(harness, actions: recorder.actions)
                try await waitForThemes(surface)
                #expect(harness.settingsData == before)
                #expect(try Data(contentsOf: directory.appending(path: "theme.json")) == manifest)
                #expect(recorder.applied.isEmpty && recorder.backgrounds.isEmpty)

                let broadcast = StateBroadcast(settings: { surface }, switcher: { nil })
                broadcast.start(harness.model)
                try harness.store.update { $0.currentTheme = "awakening" }
                try await waitForCurrent(surface, "awakening")
                #expect(recorder.applied.isEmpty && recorder.backgrounds.isEmpty)
            }
        }

        @Test(
            "dark mode, all colours and Neovim edits save the manifest and can reset to shipped data"
        )
        func editingAndReset() async throws {
            try await withHarness { harness in
                let recorder = ThemeRecorder()
                let surface = try themesPage(harness, actions: recorder.actions)
                try await waitForThemes(surface)
                try await run(
                    surface, "document.querySelector('[aria-label^=\"View lumon\" i]').click();")
                let directory = harness.themes.appending(path: "lumon")
                let wasDark = try Theme.read(from: directory).dark
                try await run(surface, "page.toggle('Dark mode').click();")
                try await waitUntil("dark mode saved") {
                    (try? Theme.read(from: directory).dark) == !wasDark
                }
                try await editThemeColours(surface)
                try await run(surface, "page.select('Neovim colourscheme').click();")
                try await waitFor(
                    surface, "Neovim default",
                    "return [...document.querySelectorAll('[role=option]')].some(o => o.textContent.includes('Theme default'));"
                )
                try await run(
                    surface,
                    "[...document.querySelectorAll('[role=option]')].find(o => o.textContent.includes('Theme default')).click();"
                )
                try await waitUntil("Neovim default saved") {
                    (try? Theme.read(from: directory).apps.nvimColorscheme) == nil
                }
                let edited = try Theme.read(from: directory)
                #expect(edited.colors.borderActive == "0xff123456")
                #expect(edited.colors.borderInactive == "0xff123456")
                #expect(edited.colors.sketchybarBar == "0xff123456")
                #expect(edited.colors.sketchybarText == "0xff123456")
                #expect(edited.colors.firefoxAccent == "#123456")
                #expect(recorder.applied.isEmpty)
                try await run(
                    surface, "document.querySelector('[aria-label=\"More actions\"]').click();")
                try await waitFor(
                    surface, "reset action",
                    "return [...document.querySelectorAll('[role=menuitem]')].some(o => o.textContent.includes('Reset to shipped version'));"
                )
                try await run(
                    surface,
                    "[...document.querySelectorAll('[role=menuitem]')].find(o => o.textContent.includes('Reset to shipped version')).click();"
                )
                try await waitFor(
                    surface, "the reset confirmation",
                    "return page.text().toLowerCase().includes('reset lumon to its shipped version?');")
                #expect(try Theme.read(from: directory) == edited)
                try await themeButton(surface, "Reset theme")
                try await waitUntil("shipped default restored") {
                    (try? Theme.read(from: directory))
                        == ThemeCatalog.bundledDefault(named: "lumon")
                }
            }
        }

        @Test("apply and wallpaper use injected operations, failures remain visible without saving")
        func actionsAndFailures() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "one.png", red: 0.3)
                let recorder = ThemeRecorder()
                var actions = recorder.actions
                actions.useBackground = { _, _, _ in
                    CommandResult(
                        command: "wallpaper", status: 1,
                        stderr: "Wallpaper rejected; some changes may already have applied.")
                }
                let surface = try themesPage(harness, actions: actions)
                try await waitForThemes(surface)
                try await run(
                    surface, "document.querySelector('[aria-label=\"Apply awakening\" i]').click();")
                try await waitUntil("recorded apply") { recorder.applied == ["awakening"] }
                try await run(
                    surface, "document.querySelector('[aria-label^=\"View lumon\" i]').click();")
                let before = harness.settingsData
                try await chooseWallpaper(surface, "backgrounds/one.png")
                try await waitFor(
                    surface, "the wallpaper failure",
                    "return page.text().includes('Wallpaper rejected');")
                #expect(harness.settingsData == before)
            }
        }

        @Test("native import and export panels are reached from page controls")
        func folderControls() async throws {
            try await withHarness { harness in
                let source = harness.home.appending(path: "portable")
                try FileManager.default.copyItem(
                    at: harness.themes.appending(path: "lumon"), to: source)
                var manifest = try Theme.read(from: source)
                manifest.name = "portable"
                try manifest.write(to: source)
                let destination = harness.home.appending(path: "exported")
                let panels = ThemePanels(
                    importFolder: { source }, exportFolder: { _ in destination }, reveal: { _ in })
                let surface = try themesPage(
                    harness, actions: ThemeRecorder().actions, panels: panels)
                try await waitForThemes(surface)
                try await themeButton(surface, "Import…")
                try await waitFor(
                    surface, "the imported theme",
                    "return !!document.querySelector('[aria-label^=\"View portable\" i]');")
                try await run(
                    surface, "document.querySelector('[aria-label^=\"View portable\" i]').click();")
                try await run(
                    surface, "document.querySelector('[aria-label=\"More actions\"]').click();")
                try await waitFor(
                    surface, "export action",
                    "return [...document.querySelectorAll('[role=menuitem]')].some(o => o.textContent.includes('Export as a folder'));"
                )
                try await run(
                    surface,
                    "[...document.querySelectorAll('[role=menuitem]')].find(o => o.textContent.includes('Export as a folder')).click();"
                )
                try await waitUntil("exported folder") {
                    Theme.load(from: destination)?.name == "portable"
                }
                #expect(try Theme.read(from: destination) == manifest)
            }
        }

        @Test("successful recorded desktop choices are reflected in saved state")
        func savedDesktopChoices() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "awakening", name: "choice.png", red: 0.4)
                let actions = ThemeActions(
                    apply: { _, name in
                        do { try harness.store.update { $0.currentTheme = name } } catch {
                            return CommandResult(
                                command: "theme", status: 1, stderr: error.localizedDescription)
                        }
                        return CommandResult(command: "theme", status: 0)
                    },
                    useBackground: { _, name, path in
                        do { try harness.store.update { $0.wallpapers[name] = path } } catch {
                            return CommandResult(
                                command: "wallpaper", status: 1, stderr: error.localizedDescription)
                        }
                        return CommandResult(command: "wallpaper", status: 0)
                    })
                let surface = try themesPage(harness, actions: actions)
                try await waitForThemes(surface)
                try await run(
                    surface, "document.querySelector('[aria-label=\"Apply awakening\" i]').click();")
                try await waitForCurrent(surface, "awakening")
                #expect(try harness.store.read().currentTheme == "awakening")
                try await run(
                    surface, "document.querySelector('[aria-label^=\"View awakening\" i]').click();")
                try await chooseWallpaper(surface, "backgrounds/choice.png")
                try await waitUntil("saved wallpaper") {
                    (try? harness.store.read().wallpapers["awakening"]) == "backgrounds/choice.png"
                }
            }
        }

        @Test("unreadable first state shows Try again and recovers after repair")
        func firstLoadFailure() async throws {
            try await withHarness { harness in
                let before = harness.settingsData
                try Data("broken".utf8).write(to: harness.store.url)
                let surface = try themesPage(harness, actions: ThemeRecorder().actions)
                try await waitFor(
                    surface, "the first load error",
                    "return page.text().includes('Could not read your themes') && page.text().includes('Try again');"
                )
                try before.write(to: harness.store.url)
                try await themeButton(surface, "Try again")
                try await waitForThemes(surface)
            }
        }
    }
}
