import Foundation
import Testing

@testable import App
@testable import Macarchy

@MainActor
struct MenuBarEditsTests {
    private func current() -> BarConfiguration {
        var clock = BarComponent(
            id: "calendar", title: "Clock", side: "right", members: ["calendar"])
        clock.colour = "0xffff0000"
        var cpu = BarComponent(id: "cpu", title: "CPU", side: "right", members: ["cpu"])
        cpu.paddingOverride = 3
        var note = BarComponent(
            id: "macarchy.note", title: "Note", side: "left", members: ["macarchy.note"])
        note.kind = "text"
        note.text = "Hi"
        var configuration = BarConfiguration()
        configuration.components = [clock, cpu, note]
        configuration.geometry = ["height": "35", "position": "top", "blur_radius": "20"]
        return configuration
    }

    private func edit(
        _ id: String, _ title: String, zone: String, visible: Bool = true, kind: String? = nil,
        text: String = "", command: String? = nil, interval: Int? = nil,
        widget: String? = nil, settings: [String: SettingValue] = [:]
    ) -> MenuBarItemEdit {
        MenuBarItemEdit(
            id: id, title: title, zone: zone, visible: visible, kind: kind, text: text, icon: "",
            command: command, interval: interval, widget: widget, settings: settings, style: nil,
            click: nil)
    }

    /// A clock that stacks its two lines, with one setting and a dropdown.
    private let catalogue: WidgetCatalogue.Snapshot = {
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        var seconds = WidgetSetting(type: "toggle", label: "Seconds")
        seconds.default = .bool(false)
        manifest.settings = ["seconds": seconds]
        manifest.style = WidgetStyle()
        manifest.style?.lines = 2
        manifest.click = WidgetClick(dropdown: [WidgetMenuRow(type: "divider")])
        var copy = manifest
        copy.id = "clock-copy"
        copy.style?.lines = 1
        return WidgetCatalogue.Snapshot(
            entries: [
                .init(
                    id: "clock", directory: URL(fileURLWithPath: "/widgets/clock"),
                    manifest: manifest, origin: .builtIn),
                .init(
                    id: "clock-copy", directory: URL(fileURLWithPath: "/mine/clock-copy"),
                    manifest: copy, origin: .user)
            ], problems: [:])
    }()

    private func configuration(_ params: MenuBarApplyParams) throws -> BarConfiguration {
        try MenuBarEdits.configuration(from: params, over: current(), catalogue: catalogue)
    }

    private let bar = MenuBarSettings(height: 30, position: "bottom", padding: 6, centre: true)

    @Test("the page's order, zones and visibility apply over every authored detail")
    func keepsAuthoredDetail() throws {
        let params = MenuBarApplyParams(
            items: [
                edit("cpu", "Processor", zone: "centre", visible: false),
                edit("calendar", "Clock", zone: "left"),
                edit("macarchy.note", "Note", zone: "right", kind: "text", text: "Bye")
            ], bar: bar)
        let result = try configuration(params)
        #expect(result.components.map(\.id) == ["cpu", "calendar", "macarchy.note"])
        #expect(result.components.map(\.side) == ["center", "left", "right"])
        #expect(result.components[0].title == "Processor" && !result.components[0].visible)
        #expect(result.components[0].paddingOverride == 3)
        #expect(result.components[1].colour == "0xffff0000")
        #expect(result.components[2].text == "Bye")
        #expect(result.geometry["height"] == "30" && result.geometry["position"] == "bottom")
        #expect(result.geometry["padding_left"] == "6" && result.geometry["padding_right"] == "6")
        #expect(result.geometry["blur_radius"] == "20")
        #expect(result.showsCentre == true)
    }

    @Test("made items left out go; the bar's own stay, and new ones are created")
    func addsAndRemoves() throws {
        let params = MenuBarApplyParams(
            items: [
                edit("calendar", "Clock", zone: "right"),
                edit(
                    "macarchy.0f3e-up", "Uptime", zone: "centre", kind: "command",
                    command: "uptime", interval: 60)
            ], bar: bar)
        let result = try configuration(params)
        #expect(result.components.map(\.id) == ["calendar", "macarchy.0f3e-up", "cpu"])
        let made = result.components[1]
        #expect(made.kind == "command" && made.command == "uptime" && made.interval == 60)
        #expect(made.members == ["macarchy.0f3e-up"])
        try result.validate()
    }

    @Test("only page-made ids become new SketchyBar items")
    func rejectsUnknownItems() {
        for id in ["battery", "macarchy.", "macarchy.Bad", "macarchy.a b", "macarchy.x;rm"] {
            let params = MenuBarApplyParams(
                items: [edit(id, "X", zone: "left", kind: "text")], bar: bar)
            #expect(throws: BridgeFailure.self) {
                try configuration(params)
            }
        }
        let wrongZone = MenuBarApplyParams(items: [edit("cpu", "CPU", zone: "middle")], bar: bar)
        #expect(throws: BridgeFailure.self) {
            try configuration(wrongZone)
        }
        let tall = MenuBarApplyParams(
            items: [], bar: MenuBarSettings(height: 200, position: "top", padding: 0, centre: false)
        )
        #expect(throws: BridgeFailure.self) {
            try configuration(tall)
        }
    }

    @Test("a widget goes on the bar in the shape it needs, keeping only edited settings")
    func addsWidget() throws {
        var item = edit(
            "macarchy.clock", "Clock", zone: "right", kind: "widget", widget: "clock",
            settings: ["seconds": .bool(false)])
        item.click = WidgetClick(open: "Calendar")
        let result = try configuration(MenuBarApplyParams(items: [item], bar: bar))
        let clock = try #require(result.components.first { $0.id == "macarchy.clock" })
        #expect(clock.widget == "clock" && clock.kind == nil && clock.settings == nil)
        #expect(clock.members == ["macarchy.clock", "macarchy.clock.lines"])
        #expect(clock.brackets == ["macarchy.clock.box"])
        #expect(clock.click == WidgetClick(open: "Calendar"))
        try result.validate()

        item.click = WidgetClick(dropdown: [WidgetMenuRow(type: "divider")])
        item.settings = ["seconds": .bool(true)]
        let again = try configuration(MenuBarApplyParams(items: [item], bar: bar))
        let edited = try #require(again.components.first { $0.id == "macarchy.clock" })
        #expect(edited.click == nil && edited.settings == ["seconds": .bool(true)])
    }

    @Test("a widget item can move to a copy of its widget, taking the copy's shape")
    func switchesWidget() throws {
        let item = edit(
            "macarchy.clock", "Clock", zone: "right", kind: "widget", widget: "clock")
        let first = try configuration(MenuBarApplyParams(items: [item], bar: bar))
        var moved = edit(
            "macarchy.clock", "Clock", zone: "right", kind: "widget", widget: "clock-copy")
        moved.settings = ["seconds": .bool(true)]
        let result = try MenuBarEdits.configuration(
            from: MenuBarApplyParams(items: [moved], bar: bar), over: first,
            catalogue: catalogue)
        let clock = try #require(result.components.first { $0.id == "macarchy.clock" })
        #expect(clock.widget == "clock-copy" && clock.settings == ["seconds": .bool(true)])
        #expect(clock.members == ["macarchy.clock"] && clock.brackets.isEmpty)
    }

    @Test("a widget item must name a widget there is, with settings it takes")
    func rejectsBadWidgets() {
        let unknown = edit("macarchy.w", "W", zone: "left", kind: "widget", widget: "weather")
        let badSetting = edit(
            "macarchy.clock", "Clock", zone: "left", kind: "widget", widget: "clock",
            settings: ["seconds": .text("yes")])
        var badClick = edit(
            "macarchy.clock", "Clock", zone: "left", kind: "widget", widget: "clock")
        badClick.click = WidgetClick(open: "A", run: "b")
        for item in [unknown, badSetting, badClick] {
            #expect(throws: BridgeFailure.self) {
                try configuration(MenuBarApplyParams(items: [item], bar: bar))
            }
        }
    }
}
