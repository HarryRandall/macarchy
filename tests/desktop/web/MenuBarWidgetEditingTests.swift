import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Widget editing")
    struct MenuBarWidgetEditingTests {
        private func prepareClock(_ harness: Harness) async throws {
            let widgets = harness.root.appending(path: "widgets")
            try FileManager.default.createDirectory(at: widgets, withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: repository.appending(path: "resources/widgets/clock"),
                to: widgets.appending(path: "clock"))
            var component = BarComponent(
                id: "macarchy.clock", title: "Clock", side: "right", members: ["macarchy.clock"]
            )
            component.widget = "clock"
            var configuration = BarConfiguration()
            configuration.components = [component]
            try harness.store.update { $0.barConfiguration = configuration }
            await harness.desktop.answer("sketchybar") { arguments in
                if arguments == ["--query", "bar"] {
                    return .success(#"{"height":35,"position":"top","items":[]}"#)
                }
                return .success()
            }
        }

        private func checkDropdownEdit(_ harness: Harness, _ surface: WebSurface) async throws {
            try WidgetMenu.save(
                "twentyFourHour", .bool(false), instance: "macarchy.clock", store: harness.store
            )
            StateBroadcast(settings: { surface }, switcher: { nil }).menuBarWritten()
            try await run(
                surface,
                #"[...document.querySelectorAll('[role=tab]')].find(b => b.textContent.trim() === 'Content').click();"#
            )
            try await waitFor(
                surface, "the dropdown edit reflected in settings",
                #"return [...document.querySelectorAll('button')].some(b => b.textContent.trim() === '24-hour clock' && b.getAttribute('aria-pressed') === 'false');"#
            )
        }

        @Test("clock drafts preview their format, icons can be hidden, and dropdown edits refresh")
        func clock() async throws {
            try await withHarness(tools: ["sketchybar"]) { harness in
                try await prepareClock(harness)
                let (_, surface) = try harness.settingsPage(pane: .menuBar)
                try await waitFor(
                    surface, "the clock preview",
                    #"return !!document.querySelector('button[aria-label="Edit Clock"]');"#)
                try await run(
                    surface, #"document.querySelector('button[aria-label="Edit Clock"]').click();"#)
                try await waitFor(
                    surface, "clock content",
                    #"return [...document.querySelectorAll('button')].some(b => b.textContent.trim() === '24-hour clock');"#
                )
                try await run(
                    surface,
                    #"[...document.querySelectorAll('button')].find(b => b.textContent.trim() === '24-hour clock').click();"#
                )
                try await waitFor(
                    surface, "the 24-hour choice",
                    #"return [...document.querySelectorAll('button')].some(b => b.textContent.trim() === '24-hour clock' && b.getAttribute('aria-pressed') === 'true');"#
                )
                try await run(surface, #"page.toggle('Seconds').click();"#)
                try await waitFor(
                    surface, "the draft time with seconds",
                    #"return /\d{2}:\d{2}:\d{2}/.test(document.querySelector('button[aria-label="Edit Clock"]').textContent);"#
                )
                #expect(
                    try harness.store.read().barConfiguration?.components.first?.settings == nil)
                try await run(
                    surface,
                    #"[...document.querySelectorAll('[role=tab]')].find(b => b.textContent.trim() === 'Look').click();"#
                )
                try await waitFor(
                    surface, "the icon control", #"return !!page.toggle('Show icon');"#)
                try await run(surface, #"page.toggle('Show icon').click();"#)
                try await waitFor(
                    surface, "the hidden icon preview",
                    #"return !document.querySelector('button[aria-label="Edit Clock"]').textContent.includes('􀧞');"#
                )
                try await run(
                    surface,
                    #"[...document.querySelectorAll('#page-content button')].find(b => b.textContent.trim() === 'Apply').click();"#
                )
                try await waitFor(
                    surface, "the saved edit",
                    #"return [...document.querySelectorAll('#page-content button')].some(b => b.textContent.trim() === 'Apply' && page.disabled(b));"#
                )
                let saved = try harness.store.read().barConfiguration?.components.first
                #expect(saved?.settings?["twentyFourHour"] == .bool(true))
                #expect(saved?.style?.showIcon == false)
                try await checkDropdownEdit(harness, surface)
            }
        }
    }
}
