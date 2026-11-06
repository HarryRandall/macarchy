import Foundation
import Testing

@testable import App
@testable import Macarchy

private let rulesDOM = """
    const rules = {
      button: (name) => [...document.querySelectorAll('button')].find(button =>
        button.getAttribute('aria-label') === name || button.textContent.trim() === name),
      field: (name) => [...document.querySelectorAll('input')].find(input =>
        [...input.labels].some(label => label.textContent.trim() === name)),
      menu: (name) => [...document.querySelectorAll('[role=menuitem]')]
        .find(item => item.textContent.trim() === name),
      // The cards have Add buttons of their own; this is the top bar's menu.
      addMenu: () => [...document.querySelectorAll('[data-slot=top-bar-actions] button')]
        .find(button => button.textContent.trim() === 'Add'),
    };
    """

@MainActor
private func rulesRun(_ surface: WebSurface, _ body: String) async throws {
    try await run(surface, rulesDOM + body)
}

@MainActor
private func rulesWait(_ surface: WebSurface, _ body: String) async throws {
    try await waitFor(surface, "Rules page", rulesDOM + body)
}

@MainActor
private func rulesPage(_ harness: Harness, unavailable: Bool = false) async throws -> WebSurface {
    await harness.desktop.answer("yabai") { arguments in
        guard arguments.starts(with: ["-m", "rule"]) else { return nil }
        if arguments.contains("--list") {
            if unavailable { return .failure("Rules unavailable") }
            return .success(
                #"[{"index":0,"label":"external","app":"^System Settings$","title":"^General$"}]"#)
        }
        return .success()
    }
    // Saved, not faked, so every shell.changed the host sends agrees.
    let (_, surface) = try harness.settingsPage(pane: .rules)
    surface.router.registerRules(model: harness.model, chooseApplication: { "Calculator" })
    try await rulesWait(
        surface,
        unavailable
            ? "return page.text().includes('Showing your saved rules');"
            : "return page.text().includes('Floating apps');")
    return surface
}

@MainActor
private func openRule(_ surface: WebSurface, item: String = "Add custom rule…") async throws {
    try await rulesRun(surface, "rules.addMenu().click();")
    let encoded = String(data: try JSONEncoder().encode(item), encoding: .utf8) ?? "\"\""
    try await rulesWait(surface, "return !!rules.menu(\(encoded));")
    try await rulesRun(surface, "rules.menu(\(encoded)).click();")
    try await rulesWait(surface, "return !!rules.field('Application');")
}

extension WebInterfaceTests {
    @MainActor
    @Suite("Rules page")
    struct RulesPageTests {
        @Test("opening reads saved and external rules without changing settings or the desktop")
        func openingReadOnly() async throws {
            try await withHarness { harness in
                try harness.store.update { $0.floatingApps = ["Messages"] }
                let before = harness.settingsData
                let surface = try await rulesPage(harness)
                try await rulesWait(
                    surface,
                    """
                    return !!rules.button('Tile instead of floating Messages')
                      && page.text().includes('System Settings')
                      && page.text().includes('Windows matching ^General$')
                      && page.text().includes('Read only');
                    """)
                #expect(harness.settingsData == before)
                let calls = await harness.desktop.calls(to: "yabai")
                #expect(!calls.contains { $0.contains("--add") || $0.contains("--remove") })
                #expect(await harness.desktop.writes.isEmpty)
            }
        }

        @Test("application picker adds a floating app and its remove button saves the change")
        func floatingApps() async throws {
            try await withHarness { harness in
                let surface = try await rulesPage(harness)
                try await rulesRun(surface, "rules.addMenu().click();")
                try await rulesWait(surface, "return !!rules.menu('Add application…');")
                try await rulesRun(surface, "rules.menu('Add application…').click();")
                try await waitUntil("Calculator saved") {
                    (try? harness.store.read().floatingApps) == ["Calculator"]
                }
                try await rulesWait(
                    surface, "return !!rules.button('Tile instead of floating Calculator');")
                #expect(
                    await harness.desktop.calls(to: "yabai").contains {
                        $0.contains("app=^Calculator$") && $0.contains("manage=off")
                    })
                try await rulesRun(
                    surface, "rules.button('Tile instead of floating Calculator').click();")
                try await waitUntil("Calculator removed") {
                    (try? harness.store.read().floatingApps.isEmpty) == true
                }
            }
        }

        @Test("presets create custom rules, editing keeps the identifier, and removal saves")
        func customEdits() async throws {
            try await withHarness { harness in
                let surface = try await rulesPage(harness)
                try await openRule(surface, item: "Finder file dialogs…")
                try await rulesWait(
                    surface, "return rules.field('Application').value === 'Finder';")
                try await rulesRun(surface, "rules.button('Save').click();")
                try await waitUntil("Finder rule saved") {
                    (try? harness.store.read().windowRules?.count) == 1
                }
                let original = try #require(harness.store.read().windowRules?.first)
                #expect(original.title == "^Copy$|^Move$|^Delete$|^Trash$")
                #expect(await harness.desktop.calls(to: "yabai").contains(original.arguments))
                try await rulesWait(surface, "return !!rules.button('Edit rule for Finder');")
                try await rulesRun(surface, "rules.button('Edit rule for Finder').click();")
                try await rulesWait(surface, "return !!rules.field('Window title');")
                try await rulesRun(surface, "page.setValue(rules.field('Window title'), '^Copy$');")
                try await rulesRun(surface, "rules.button('Save').click();")
                try await waitUntil("rule edited") {
                    (try? harness.store.read().windowRules?.first?.title) == "^Copy$"
                }
                #expect(try harness.store.read().windowRules?.first?.id == original.id)
                try await rulesWait(surface, "return !rules.field('Application');")
                try await rulesRun(surface, "rules.button('Remove rule for Finder').click();")
                try await rulesWait(
                    surface, "return page.text().includes('Remove the rule for Finder?');")
                #expect(try harness.store.read().windowRules?.count == 1)
                try await rulesRun(surface, "rules.button('Remove rule').click();")
                try await waitUntil("rule removed") {
                    (try? harness.store.read().windowRules?.isEmpty) == true
                }
            }
        }

        @Test("invalid patterns and refused applies stay visible and leave saved bytes unchanged")
        func failedEdits() async throws {
            try await withHarness { harness in
                let surface = try await rulesPage(harness)
                let before = harness.settingsData
                try await openRule(surface, item: "Calculator…")
                try await rulesRun(surface, "page.setValue(rules.field('Window title'), '[');")
                try await rulesRun(surface, "rules.button('Save').click();")
                try await rulesWait(
                    surface, "return page.text().includes('Invalid window title pattern');")
                #expect(harness.settingsData == before)
                await harness.desktop.answer("yabai") { arguments in
                    arguments.contains("app=^Calculator$")
                        ? .failure("Rule rejected by yabai") : nil
                }
                try await rulesRun(surface, "page.setValue(rules.field('Window title'), '');")
                try await rulesRun(surface, "rules.button('Save').click();")
                try await rulesWait(
                    surface, "return page.text().includes('Rule rejected by yabai');")
                #expect(harness.settingsData == before)
                try await rulesWait(surface, "return !!rules.field('Application');")
            }
        }

        @Test(
            "saving an open editor for a rule removed elsewhere explains and does not recreate it")
        func removedElsewhere() async throws {
            try await withHarness { harness in
                let rule = CustomWindowRule(app: "Finder", title: "^Copy$")
                try harness.store.update { $0.windowRules = [rule] }
                let surface = try await rulesPage(harness)
                try await rulesWait(surface, "return !!rules.button('Edit rule for Finder');")
                try await rulesRun(surface, "rules.button('Edit rule for Finder').click();")
                try await rulesWait(surface, "return !!rules.field('Window title');")
                try harness.store.update { $0.windowRules = [] }
                let before = harness.settingsData
                try await rulesRun(surface, "page.setValue(rules.field('Window title'), '^Move$');")
                try await rulesRun(surface, "rules.button('Save').click();")
                try await rulesWait(
                    surface, "return page.text().includes('This rule was removed elsewhere.');")
                #expect(harness.settingsData == before)
                #expect(try harness.store.read().windowRules?.isEmpty == true)
                #expect(
                    !(await harness.desktop.calls(to: "yabai")).contains {
                        $0.contains("title=^Move$")
                    })
            }
        }

        @Test("a stopped yabai shows saved rules without editing, and Try again reads live state")
        func retryLoad() async throws {
            try await withHarness { harness in
                try harness.store.update { $0.floatingApps = ["Messages"] }
                let before = harness.settingsData
                let surface = try await rulesPage(harness, unavailable: true)
                try await rulesWait(
                    surface,
                    """
                    return !!rules.button('Try again')
                      && page.disabled(rules.button('Tile instead of floating Messages'))
                      && page.disabled(rules.addMenu())
                      && page.disabled(rules.button('Add an app to float'))
                      && !page.text().includes('Could not read your rules');
                    """)
                await harness.desktop.answer(
                    "yabai", ["-m", "rule", "--list"], with: .success("[]"))
                try await rulesRun(surface, "rules.button('Try again').click();")
                try await rulesWait(
                    surface,
                    """
                    return !page.text().includes('Showing your saved rules')
                      && !page.disabled(rules.button('Tile instead of floating Messages'))
                      && !page.disabled(rules.addMenu());
                    """)
                #expect(harness.settingsData == before)
            }
        }

        @Test(
            "external settings changes arrive through the watcher without replacing an open draft")
        func externalChange() async throws {
            try await withHarness { harness in
                let surface = try await rulesPage(harness)
                let broadcast = StateBroadcast(settings: { surface }, switcher: { nil })
                broadcast.start(harness.model)
                try await openRule(surface, item: "Calculator…")
                try await rulesRun(
                    surface, "page.setValue(rules.field('Window title'), '^My draft$');")
                try harness.store.update { $0.floatingApps = ["Messages"] }
                try await rulesWait(
                    surface,
                    """
                    return !!rules.button('Tile instead of floating Messages')
                      && rules.field('Application').value === 'Calculator'
                      && rules.field('Window title').value === '^My draft$';
                    """)
                withExtendedLifetime(broadcast) {}
            }
        }
    }
}
