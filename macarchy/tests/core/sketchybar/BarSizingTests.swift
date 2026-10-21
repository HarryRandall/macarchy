import Foundation
import Testing
@testable import Macarchy

@Suite("Component sizing and visual order")
struct BarSizingTests {
    @Test func moveOneKeepsSideAndOtherAreas() {
        var configuration = BarConfiguration()
        configuration.components = [
            BarComponent(id: "network", title: "Network", side: "right", members: ["network"]),
            BarComponent(id: "spaces", title: "Spaces", side: "left", members: ["spaces"]),
            BarComponent(id: "memory", title: "Memory", side: "right", members: ["memory"]),
            BarComponent(id: "cpu", title: "CPU", side: "right", members: ["cpu"])
        ]
        configuration.moveOne("memory", direction: 1)
        #expect(
            configuration.components.filter { $0.side == "right" }.map(\.id) == [
                "network", "cpu", "memory"
            ])
        #expect(configuration.components[1].id == "spaces")
        configuration.moveOne("memory", direction: 1)
        #expect(configuration.components.last?.id == "memory")
        configuration.moveOne("memory", direction: -1)
        #expect(
            configuration.components.filter { $0.side == "right" }.map(\.id) == [
                "network", "memory", "cpu"
            ])
        #expect(
            configuration.components.allSatisfy {
                $0.id == "spaces" ? $0.side == "left" : $0.side == "right"
            })
    }

    @Test func explicitWidthRoundTripsAndRejectsInvalidSizes() throws {
        var component = BarComponent(id: "cpu", title: "CPU", side: "right", members: ["cpu"])
        component.boxWidth = 88
        let data = try JSONEncoder().encode(component)
        #expect(try JSONDecoder().decode(BarComponent.self, from: data).boxWidth == 88)
        var configuration = BarConfiguration()
        configuration.components = [component]
        try configuration.validate()
        configuration.components[0].boxWidth = -1
        #expect(throws: ConfigurationError.self) { try configuration.validate() }
    }

    @Test func customWidthIsAppliedAndReplayed() {
        var old = BarConfiguration()
        var component = BarComponent(id: "text", title: "Text", side: "right", members: ["text"])
        component.kind = "text"
        component.text = "Hello"
        old.components = [component]
        var draft = old
        draft.components[0].boxWidth = 90
        #expect(BarCommands.changes(draft, from: old, baseline: [:]).contains("width=90.0"))
        #expect(BarCommands.settings(draft, startup: true).contains("width=90.0"))
    }
}
