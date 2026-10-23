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
        text: String = "", command: String? = nil, interval: Int? = nil
    ) -> MenuBarItemEdit {
        MenuBarItemEdit(
            id: id, title: title, zone: zone, visible: visible, kind: kind, text: text, icon: "",
            command: command, interval: interval)
    }

    private let bar = MenuBarSettings(height: 30, position: "bottom", padding: 6)

    @Test("the page's order, zones and visibility apply over every authored detail")
    func keepsAuthoredDetail() throws {
        let params = MenuBarApplyParams(
            items: [
                edit("cpu", "Processor", zone: "centre", visible: false),
                edit("calendar", "Clock", zone: "left"),
                edit("macarchy.note", "Note", zone: "right", kind: "text", text: "Bye")
            ], bar: bar)
        let result = try MenuBarEdits.configuration(from: params, over: current())
        #expect(result.components.map(\.id) == ["cpu", "calendar", "macarchy.note"])
        #expect(result.components.map(\.side) == ["center", "left", "right"])
        #expect(result.components[0].title == "Processor" && !result.components[0].visible)
        #expect(result.components[0].paddingOverride == 3)
        #expect(result.components[1].colour == "0xffff0000")
        #expect(result.components[2].text == "Bye")
        #expect(result.geometry["height"] == "30" && result.geometry["position"] == "bottom")
        #expect(result.geometry["padding_left"] == "6" && result.geometry["padding_right"] == "6")
        #expect(result.geometry["blur_radius"] == "20")
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
        let result = try MenuBarEdits.configuration(from: params, over: current())
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
                try MenuBarEdits.configuration(from: params, over: current())
            }
        }
        let wrongZone = MenuBarApplyParams(items: [edit("cpu", "CPU", zone: "middle")], bar: bar)
        #expect(throws: BridgeFailure.self) {
            try MenuBarEdits.configuration(from: wrongZone, over: current())
        }
        let tall = MenuBarApplyParams(
            items: [], bar: MenuBarSettings(height: 200, position: "top", padding: 0))
        #expect(throws: BridgeFailure.self) {
            try MenuBarEdits.configuration(from: tall, over: current())
        }
    }
}
