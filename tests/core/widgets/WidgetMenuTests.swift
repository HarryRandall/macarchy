import Foundation
import Testing

@testable import Macarchy

@Suite("Widget dropdowns")
struct WidgetMenuTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "menu-\(UUID())")

    private func manifest() -> WidgetManifest {
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        manifest.provider = "provider.sh"
        manifest.settings = [
            "twentyFourHour": WidgetSetting(
                type: "toggle", label: "24-hour", default: .bool(false)),
            "order": {
                var setting = WidgetSetting(type: "choice", label: "Order", default: .text("day"))
                setting.options = ["day", "month"]
                return setting
            }()
        ]
        var heading = WidgetMenuRow(type: "heading", label: "{weekday} {label}")
        heading.value = "{unit}"
        var toggle = WidgetMenuRow(type: "toggle", label: "24-hour clock")
        toggle.setting = "twentyFourHour"
        var choice = WidgetMenuRow(type: "choice", label: "Order")
        choice.setting = "order"
        var reading = WidgetMenuRow(type: "choice", value: "{mode}")
        reading.options = ["Automatic", "Low Power"]
        var open = WidgetMenuRow(type: "action", label: "Open Calendar")
        open.open = "Calendar"
        var run = WidgetMenuRow(type: "action", label: "Say hi")
        run.run = "say hi"
        manifest.click = WidgetClick(dropdown: [
            heading, WidgetMenuRow(type: "divider"), toggle, choice, reading, open, run
        ])
        return manifest
    }

    private func instance(_ settings: [String: SettingValue] = [:]) -> WidgetInstance {
        WidgetInstance(
            id: "macarchy.clock", manifest: manifest(), directory: root,
            settings: ["twentyFourHour": .bool(false), "order": .text("day")].merging(settings) {
                $1
            },
            visible: true)
    }

    @Test("rows are filled from the latest reading, the settings and the label")
    func items() {
        var output = WidgetOutput(values: ["weekday": "Friday", "mode": "Low Power"])
        output.label = "ignored"
        let items = WidgetMenu.items(
            instance: instance(), component: nil, output: output, label: "3:41 PM")
        #expect(
            items.map(\.type) == [
                "heading", "divider", "toggle", "choice", "choice", "action", "action"
            ])
        #expect(items[0].label == "Friday 3:41 PM")
        #expect(items[0].value == "{unit}")
        #expect(items[2].checked == false && items[2].enabled)
        #expect(
            items[3].options == ["day", "month"] && items[3].selected == "day" && items[3].enabled)
        #expect(items[4].selected == "Low Power" && !items[4].enabled)
        #expect(items[5].enabled && !items[0].enabled)
    }

    @Test("an edited menu replaces the widget's own, and provider rows do too")
    func overrides() {
        var component = BarComponent(
            id: "macarchy.clock", title: "Clock", side: "right", members: ["macarchy.clock"])
        component.menu = [WidgetMenuRow(type: "text", label: "Mine")]
        #expect(
            WidgetMenu.items(instance: instance(), component: component, output: nil, label: "")
                .map(\.label) == ["Mine"])
        var output = WidgetOutput()
        output.rows = [WidgetMenuRow(type: "text", label: "Live")]
        #expect(
            WidgetMenu.items(instance: instance(), component: nil, output: output, label: "")
                .map(\.label) == ["Live"])
    }

    @Test("picking a row opens, runs, flips a toggle or picks an option")
    func effects() {
        func effect(
            _ row: Int, _ option: String? = nil, settings: [String: SettingValue] = [:]
        )
            -> WidgetMenu.Effect
        {
            WidgetMenu.effect(
                of: row, option: option, instance: instance(settings), component: nil, output: nil)
        }
        #expect(effect(5) == .open("Calendar"))
        #expect(effect(6) == .run("say hi"))
        #expect(effect(2) == .set("twentyFourHour", .bool(true)))
        #expect(
            effect(2, settings: ["twentyFourHour": .bool(true)])
                == .set("twentyFourHour", .bool(false)))
        #expect(effect(3, "month") == .set("order", .text("month")))
        #expect(effect(3, "sideways") == .nothing)
        #expect(effect(4, "Automatic") == .nothing)
        #expect(effect(0) == .nothing && effect(99) == .nothing)
    }

    @Test("a picked setting is saved on that widget only, and the widget redrawn")
    func pick() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = SettingsStore(url: root.appending(path: "settings.json"))
        var component = BarComponent(
            id: "macarchy.clock", title: "Clock", side: "right", members: ["macarchy.clock"])
        component.widget = "clock"
        try store.update { settings in
            var configuration = BarConfiguration()
            configuration.components = [component]
            settings.barConfiguration = configuration
        }
        let snapshot = WidgetCatalogue.Snapshot(
            entries: [.init(id: "clock", directory: root, manifest: manifest(), origin: .user)],
            problems: [:])
        let host = WidgetHost(
            integrations: Integrations { _, _ in CommandResult(command: "sketchybar", status: 0) },
            runner: WidgetProviderRunner { _, _, _, _ in
                CommandResult(command: "p", status: 0, stdout: "x")
            },
            load: { (try? store.read().barConfiguration, snapshot) }, store: store,
            look: { WidgetLook() })
        await host.reload()
        let effect = try await host.pick(2, in: "macarchy.clock")
        #expect(effect == .set("twentyFourHour", .bool(true)))
        let saved = try store.read().barConfiguration?.components.first?.settings
        #expect(saved == ["twentyFourHour": .bool(true)])
        #expect(await host.menu(for: "macarchy.clock")?[2].checked == true)
        #expect(await host.menu(for: "macarchy.nothing") == nil)
    }
}
