import Foundation
import Testing

@testable import Macarchy

/// Moving whole bars from before the widget bar onto widgets, as setup does.
@Suite("Moving a bar onto widgets")
struct WidgetBarMoveTests {
    private func native(
        _ id: String, _ title: String, side: String = "right", visible: Bool = true
    ) -> BarComponent {
        BarComponent(
            id: id, title: title, side: side, members: [id, "gap.\(id)"], visible: visible)
    }

    private func widget(_ name: String, side: String = "right") -> BarComponent {
        var component = BarComponent(
            id: "macarchy.\(name)", title: name.capitalized, side: side,
            members: ["macarchy.\(name)"])
        component.widget = name
        return component
    }

    private var defaultIDs: [String] {
        BarConfiguration.widgetDefault.components.map(\.id)
    }

    @Test("a new install starts with Spaces, then network to clock, on the owner's bar")
    func defaultLayout() throws {
        let bar = BarConfiguration.widgetDefault
        #expect(
            bar.components.map(\.widget) == [
                "spaces", "network", "memory", "gpu", "cpu", "battery", "clock"
            ])
        #expect(bar.components.map(\.side) == ["left"] + Array(repeating: "right", count: 6))
        #expect(
            bar.geometry == [
                "height": "35", "position": "top", "sticky": "on", "padding_left": "10",
                "padding_right": "10", "blur_radius": "0", "corner_radius": "0", "y_offset": "0"
            ])
        #expect(bar.componentPadding == 0 && bar.componentSpacing == 4)
        try bar.validate()
    }

    @Test("nothing saved moves onto the default layout")
    func nothingSaved() {
        let move = WidgetMigration.moveBar(nil, taken: [])
        #expect(move.configuration == .widgetDefault && move.startedFromDefault)
        #expect(move.newWidgets.isEmpty && move.removed.isEmpty)
    }

    /// The owner's bar today: their own items hidden, widgets shown.
    @Test("an own bar already showing widgets keeps only the widgets")
    func ownBarWithWidgets() throws {
        var configuration = BarConfiguration()
        configuration.geometry = ["height": "35"]
        configuration.components =
            [
                native("theme_listener", "Theme Listener", side: "left", visible: false),
                native("workspaces", "Workspaces", side: "left", visible: false),
                widget("spaces", side: "left"), native("ram", "Memory", visible: false),
                native("calendar", "Clock", visible: false)
            ] + ["network", "memory", "gpu", "cpu", "battery", "clock"].map { widget($0) }
        let move = WidgetMigration.moveBar(configuration, taken: [])
        #expect(move.configuration.components.map(\.id) == defaultIDs)
        #expect(move.removed == ["Theme Listener", "Workspaces", "Memory", "Clock"])
        #expect(move.replaced.isEmpty && move.duplicates.isEmpty && move.unmatched.isEmpty)
        #expect(!move.startedFromDefault && move.newWidgets.isEmpty)
        #expect(move.configuration.geometry["height"] == "35")
        #expect(move.configuration.geometry["position"] == "top")
        try move.configuration.validate()
    }

    /// The owner's bar before widgets: every item their own scripts made.
    @Test("an own bar's items become the same widgets in the same places")
    func ownBarItems() throws {
        var spacer = BarComponent(
            id: "macarchy.gap", title: "Spacer", side: "right", members: ["macarchy.gap"])
        spacer.kind = "spacer"
        var configuration = BarConfiguration()
        configuration.components = [
            BarComponent(
                id: "workspaces", title: "Workspaces", side: "left",
                members: (1...10).map { "space.\($0)" }),
            native("network", "Network"), native("ram", "Memory"), native("gpu", "GPU"),
            native("cpu", "CPU"), native("battery", "Battery"), spacer,
            native("calendar", "Clock"),
            native("theme_listener", "Theme Listener", side: "left", visible: false)
        ]
        let move = WidgetMigration.moveBar(configuration, taken: [])
        let ids = move.configuration.components.map(\.id)
        #expect(ids == defaultIDs.dropLast() + ["macarchy.gap", "macarchy.clock"])
        #expect(
            move.replaced == ["Workspaces", "Network", "Memory", "GPU", "CPU", "Battery", "Clock"])
        #expect(move.removed == ["Theme Listener"])
        try move.configuration.validate()
    }

    @Test("an item whose widget is on the bar already, or replaced twice, goes")
    func duplicates() {
        var configuration = BarConfiguration()
        configuration.components = [
            widget("cpu"), native("cpu", "CPU"), native("memory", "Memory"), native("ram", "RAM")
        ]
        let move = WidgetMigration.moveBar(configuration, taken: [])
        #expect(move.configuration.components.map(\.id) == ["macarchy.cpu", "macarchy.memory"])
        #expect(move.duplicates == ["CPU", "RAM"] && move.replaced == ["Memory"])
    }

    @Test("items no widget replaces are named, and command items become scripted widgets")
    func unmatchedAndCommands() throws {
        var command = BarComponent(
            id: "macarchy.uptime", title: "Uptime", side: "right", members: ["macarchy.uptime"])
        command.kind = "command"
        command.command = "uptime"
        command.interval = 60
        var configuration = BarConfiguration()
        configuration.components = [native("weather", "Weather"), native("cpu", "CPU"), command]
        let move = WidgetMigration.moveBar(configuration, taken: [])
        #expect(move.configuration.components.map(\.id) == ["macarchy.cpu", "macarchy.uptime"])
        #expect(move.unmatched == ["Weather"])
        #expect(move.newWidgets.map(\.manifest.id) == ["uptime"])
        #expect(move.configuration.components.last?.widget == "uptime")
        try move.configuration.validate()
    }

    @Test("a bar with nothing that becomes a widget starts from the default, keeping text")
    func nothingConvertible() {
        var text = BarComponent(
            id: "macarchy.note", title: "Note", side: "left", members: ["macarchy.note"])
        text.kind = "text"
        text.text = "hello"
        var configuration = BarConfiguration()
        configuration.components = [native("weather", "Weather"), text]
        let move = WidgetMigration.moveBar(configuration, taken: [])
        #expect(move.startedFromDefault && move.unmatched == ["Weather"])
        #expect(move.configuration.components.map(\.id) == defaultIDs + ["macarchy.note"])
    }
}
