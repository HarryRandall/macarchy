import Foundation
import Testing

@testable import App
@testable import Macarchy

extension WebInterfaceTests {
    @MainActor
    @Suite("Themes bridge without WebKit", ThemeResources())
    struct ThemesBridgeTests {
        @Test("native folder panels import, export and cancel without exposing paths to the page")
        func panels() async throws {
            try await withHarness { harness in
                let router = BridgeRouter()
                let source = harness.home.appending(path: "imported")
                try FileManager.default.copyItem(
                    at: harness.themes.appending(path: "lumon"), to: source)
                var manifest = try Theme.read(from: source)
                manifest.name = "imported"
                try manifest.write(to: source)
                let destination = harness.home.appending(path: "exported")
                var reveals: [URL] = []
                router.registerThemes(
                    model: harness.model, actions: ThemeRecorder().actions,
                    panels: ThemePanels(
                        importFolder: { source }, exportFolder: { _ in destination },
                        reveal: { reveals.append($0) }))
                let imported = await router.handle(["method": "themes.importFolder"])
                #expect(imported.contains("\"ok\":true"))
                #expect(!imported.contains(source.path))
                #expect(
                    Theme.load(from: harness.themes.appending(path: "imported"))?.name == "imported"
                )
                let exported = await router.handle([
                    "method": "themes.exportFolder", "params": ["theme": "imported"]
                ])
                #expect(exported.contains("\"ok\":true"))
                #expect(try Theme.read(from: destination) == manifest)
                _ = await router.handle(["method": "themes.reveal", "params": ["theme": "imported"]]
                )
                #expect(
                    reveals.map(\.path) == [
                        harness.themes.appending(path: "imported").resolvingSymlinksInPath().path
                    ])
                router.registerThemes(
                    model: harness.model, actions: ThemeRecorder().actions,
                    panels: ThemePanels(
                        importFolder: { nil }, exportFolder: { _ in nil }, reveal: { _ in }))
                let before = try FileManager.default.contentsOfDirectory(
                    atPath: harness.themes.path)
                _ = await router.handle(["method": "themes.importFolder"])
                _ = await router.handle([
                    "method": "themes.exportFolder", "params": ["theme": "lumon"]
                ])
                #expect(
                    try FileManager.default.contentsOfDirectory(atPath: harness.themes.path)
                        == before)
            }
        }

        @Test("validated setters preserve fields, nullable contract values and failures")
        func setters() async throws {
            try await withHarness { harness in
                let router = BridgeRouter()
                let recorder = ThemeRecorder()
                router.registerThemes(model: harness.model, actions: recorder.actions)
                let directory = harness.themes.appending(path: "lumon")
                let before = harness.settingsData
                let dark = await router.handle([
                    "method": "themes.setDark", "params": ["theme": "lumon", "dark": false]
                ])
                #expect(dark.contains("\"ok\":true"))
                #expect(try !Theme.read(from: directory).dark)
                for colour in [
                    "borderActive", "borderInactive", "sketchybarBar", "sketchybarText",
                    "firefoxAccent"
                ] {
                    let reply = await router.handle([
                        "method": "themes.setColour",
                        "params": ["theme": "lumon", "colour": colour, "value": "#123456"]
                    ])
                    #expect(reply.contains("\"ok\":true"))
                }
                _ = await router.handle([
                    "method": "themes.setColourscheme",
                    "params": ["theme": "lumon", "value": NSNull()]
                ])
                #expect(try Theme.read(from: directory).apps.nvimColorscheme == nil)
                let data = try Data(contentsOf: directory.appending(path: "theme.json"))
                for params in [
                    ["theme": "../lumon", "colour": "borderActive", "value": "#123456"],
                    ["theme": "lumon", "colour": "borderActive", "value": "no"]
                ] {
                    let reply = await router.handle(["method": "themes.setColour", "params": params]
                    )
                    #expect(reply.contains("\"ok\":false"))
                }
                #expect(try Data(contentsOf: directory.appending(path: "theme.json")) == data)
                #expect(harness.settingsData == before)
                #expect(recorder.applied.isEmpty && recorder.backgrounds.isEmpty)
                let state = await router.handle(["method": "themes.getState"])
                #expect(state.contains("\"nvimColorscheme\":null"))
                _ = await router.handle(["method": "themes.reset", "params": ["theme": "lumon"]])
                #expect(
                    try Theme.read(from: directory) == ThemeCatalog.bundledDefault(named: "lumon"))
            }
        }

        @Test("desktop failures propagate and wallpaper paths are validated before actions")
        func actions() async throws {
            try await withHarness { harness in
                try harness.addBackground(theme: "lumon", name: "one.png", red: 0.5)
                let router = BridgeRouter()
                var calls: [String] = []
                let actions = ThemeActions(
                    apply: { _, name in
                        calls.append(name)
                        return CommandResult(
                            command: "theme", status: 1, stderr: "Partly applied; not saved")
                    },
                    useBackground: { _, name, path in
                        calls.append(path)
                        return CommandResult(command: name, status: 1, stderr: "Wallpaper failed")
                    })
                router.registerThemes(model: harness.model, actions: actions)
                #expect(
                    try harness.model.themesState().themes.first(where: {
                        $0.summary.name == "lumon"
                    })?.summary.backgrounds.first?.path == "backgrounds/one.png")
                let before = harness.settingsData
                let bad = await router.handle([
                    "method": "themes.chooseWallpaper",
                    "params": ["theme": "lumon", "path": "../secret.png"]
                ])
                #expect(bad.contains("\"ok\":false"))
                #expect(calls.isEmpty)
                let apply = await router.handle([
                    "method": "themes.apply", "params": ["theme": "lumon"]
                ])
                #expect(apply.contains("Partly applied; not saved"))
                let choose = await router.handle([
                    "method": "themes.chooseWallpaper",
                    "params": ["theme": "lumon", "path": "backgrounds/one.png"]
                ])
                #expect(choose.contains("Wallpaper failed"))
                #expect(calls == ["lumon", "backgrounds/one.png"])
                #expect(harness.settingsData == before)
            }
        }
    }
}
