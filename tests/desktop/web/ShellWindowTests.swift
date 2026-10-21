import AppKit
import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    /// Preferences go to the development suite only in an isolated run, so
    /// these use the harness's temporary home.
    @MainActor
    @Suite("Shell window and services")
    struct ShellWindowTests {
        @Test("the appearance choice is stored and set on the open window and on a new one")
        func appearance() async throws {
            try await withHarness { harness in
                InterfacePreferences.appearance = .system
                let (_, surface) = try harness.settingsPage(pane: .home)
                let window = try #require(surface.webView.window)
                #expect(window.appearance == nil)

                let dark = await choose("dark", on: surface)
                #expect(dark == #"{"ok":true,"value":null}"#)
                #expect(InterfacePreferences.appearance == .dark)
                #expect(window.appearance?.name == .darkAqua)
                #expect(harness.model.shellState().appearance.mode == .dark)

                let (_, reopened) = try harness.settingsPage(pane: .home)
                #expect(reopened.webView.window?.appearance?.name == .darkAqua)

                _ = await choose("light", on: surface)
                #expect(window.appearance?.name == .aqua)
                _ = await choose("system", on: surface)
                #expect(window.appearance == nil)
                #expect(InterfacePreferences.appearance == .system)

                let invalid = await choose("sepia", on: surface)
                #expect(invalid.contains("invalid_params"))
                #expect(InterfacePreferences.appearance == .system)
            }
        }

        @Test("shell state names every service with the monitor's reading and a version")
        func services() async throws {
            try await withHarness(tools: ["launchctl"]) { harness in
                await harness.desktop.answer("launchctl") { arguments in
                    guard arguments.first == "print" else { return nil }
                    return arguments.last?.contains("yabai") == true
                        ? .success("state = running\npid = 42")
                        : .failure("Could not find service", status: 113)
                }
                await harness.model.daemons.refresh()
                let state = harness.model.shellState()
                #expect(
                    state.serviceList.map(\.name) == ["yabai", "borders", "SketchyBar", "skhd"])
                #expect(state.serviceList.map(\.id) == [.yabai, .borders, .sketchybar, .skhd])
                #expect(state.serviceList.map(\.state) == [.running, .stopped, .stopped, .stopped])
                #expect(state.services == .init(running: 1, total: 4))
                #expect(!state.version.isEmpty)
            }
        }
    }
}

@MainActor
private func choose(_ appearance: String, on surface: WebSurface) async -> String {
    await surface.router.handle([
        "method": "shell.setPreferences", "params": ["appearance": appearance]
    ])
}
