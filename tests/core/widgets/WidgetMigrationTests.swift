import Foundation
import Testing

@testable import Macarchy

@Suite("Widget migration")
struct WidgetMigrationTests {
    /// The shape of a real bar saved before widgets: the bar's own items,
    /// an empty spacer, a hidden helper and a command item.
    private func savedBar() -> BarConfiguration {
        var configuration = BarConfiguration()
        let spaces = (1...3).map { "space.\($0)" }
        configuration.components = [
            BarComponent(id: "workspaces", title: "Workspaces", side: "left", members: spaces),
            BarComponent(
                id: "network", title: "Network", side: "right",
                members: ["network.icon", "network.text", "gap.network"]),
            BarComponent(
                id: "cpu", title: "CPU", side: "right",
                members: ["cpu.icon", "cpu.text", "gap.cpu"],
                brackets: ["cpu.bracket"]),
            BarComponent(
                id: "battery", title: "Battery", side: "right", members: ["battery", "gap.battery"],
                visible: false),
            BarComponent(
                id: "calendar", title: "Calendar", side: "right",
                members: ["calendar", "gap.calendar"]),
            BarComponent(
                id: "theme_listener", title: "theme_listener", side: "left",
                members: ["theme_listener"], visible: false)
        ]
        configuration.components[4].colour = "0xffa5b4fc"
        var spacer = BarComponent(
            id: "macarchy.gap", title: "Spacer", side: "right", members: ["macarchy.gap"])
        spacer.kind = "spacer"
        var command = BarComponent(
            id: "macarchy.uptime", title: "Uptime", side: "right", members: ["macarchy.uptime"])
        command.kind = "command"
        command.command = "uptime | cut -d, -f1"
        command.interval = 60
        command.icon = "⏱"
        configuration.components.insert(spacer, at: 2)
        configuration.components.append(command)
        return configuration
    }

    @Test("the bar's clock, CPU and battery become built-in widgets in the same places")
    func builtIns() throws {
        let result = WidgetMigration.migrate(savedBar(), taken: ["clock", "cpu", "battery"])
        let ids = result.configuration.components.map(\.id)
        #expect(
            ids == [
                "workspaces", "network", "macarchy.gap", "macarchy.cpu", "macarchy.battery",
                "macarchy.clock", "theme_listener", "macarchy.uptime"
            ])
        let clock = try #require(
            result.configuration.components.first { $0.id == "macarchy.clock" })
        #expect(clock.widget == "clock" && clock.members == ["macarchy.clock"])
        #expect(clock.side == "right" && clock.colour == "0xffa5b4fc")
        let battery = try #require(result.configuration.components.first { $0.widget == "battery" })
        #expect(!battery.visible)
        #expect(result.configuration.components.first { $0.id == "network" }?.widget == nil)
        try result.configuration.validate()
    }

    @Test("a command item becomes a widget of its own that runs the same command")
    func command() throws {
        let result = WidgetMigration.migrate(savedBar(), taken: ["clock", "cpu", "battery"])
        let widget = try #require(result.newWidgets.first)
        #expect(result.newWidgets.count == 1)
        #expect(widget.manifest.id == "uptime" && widget.manifest.name == "Uptime")
        #expect(widget.manifest.provider == "provider.sh")
        #expect(widget.manifest.update == WidgetUpdate(every: "60s"))
        #expect(widget.manifest.icon == "⏱")
        #expect(widget.manifest.isScripted)
        #expect(widget.provider.contains("\nuptime | cut -d, -f1\n"))
        let component = try #require(result.configuration.components.last)
        #expect(component.widget == "uptime")
        #expect(component.kind == nil && component.command == nil && component.interval == nil)
        #expect(component.members == ["macarchy.uptime"])
    }

    @Test("a new widget id steps around ones already taken")
    func taken() {
        let result = WidgetMigration.migrate(savedBar(), taken: ["uptime", "uptime-2"])
        #expect(result.newWidgets.map(\.manifest.id) == ["uptime-3"])
        #expect(result.configuration.components.last?.widget == "uptime-3")
    }

    @Test(
        "ids are made from command item ids",
        arguments: [
            ("macarchy.uptime", "uptime"), ("macarchy.Wi_Fi Speed", "wi-fi-speed"),
            ("macarchy.!!", "command")
        ])
    func ids(id: String, expected: String) {
        let component = BarComponent(id: id, title: "X", side: "right", members: [id])
        #expect(WidgetMigration.widgetID(for: component) == expected)
    }

    @Test("running it again changes nothing")
    func idempotent() {
        let once = WidgetMigration.migrate(savedBar(), taken: [])
        let twice = WidgetMigration.migrate(once.configuration, taken: ["uptime"])
        #expect(twice.configuration == once.configuration)
        #expect(twice.newWidgets.isEmpty)
    }

    @Test("writes working widget folders and never replaces one")
    func write() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "migrated-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let result = WidgetMigration.migrate(savedBar(), taken: [])
        try WidgetMigration.write(result.newWidgets, to: root)
        let folder = root.appending(path: "uptime")
        #expect(WidgetManifest.check(folder: folder).ok)
        let output = await CommandRunner.run(folder.appending(path: "provider.sh").path, [])
        #expect(output.ok && !output.stdout.isEmpty)
        #expect(throws: ConfigurationError.self) {
            try WidgetMigration.write(result.newWidgets, to: root)
        }
    }

    @Test("a widget instance names a widget, is its own single item and has sensible setting names")
    func validation() throws {
        var instance = BarComponent(
            id: "macarchy.clock", title: "Clock", side: "right", members: ["macarchy.clock"])
        instance.widget = "clock"
        instance.settings = ["seconds": .bool(true)]
        var configuration = BarConfiguration()
        configuration.components = [instance]
        try configuration.validate()
        for broken in [
            { (component: inout BarComponent) in component.widget = "Clock!" },
            { (component: inout BarComponent) in component.kind = "text" },
            { (component: inout BarComponent) in component.members = ["macarchy.clock", "gap.clock"]
            },
            { (component: inout BarComponent) in component.settings = ["Seconds": .bool(true)] }
        ] {
            var component = instance
            broken(&component)
            configuration.components = [component]
            #expect(throws: ConfigurationError.self) { try configuration.validate() }
        }
    }

    @Test("an instance round-trips through JSON and an old bar still decodes")
    func coding() throws {
        var instance = BarComponent(
            id: "macarchy.clock", title: "Clock", side: "right", members: ["macarchy.clock"])
        instance.widget = "clock"
        instance.settings = ["order": .text("month-day")]
        instance.menu = [WidgetMenuRow(type: "divider")]
        let decoded = try JSONDecoder().decode(
            BarComponent.self, from: JSONEncoder().encode(instance))
        #expect(decoded == instance)
        let old = #"{"id":"x","title":"X","side":"left","members":["x"]}"#
        let component = try JSONDecoder().decode(BarComponent.self, from: Data(old.utf8))
        #expect(component.widget == nil && component.settings == nil && component.menu == nil)
    }
}
