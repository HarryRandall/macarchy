import Macarchy
import Foundation
import Testing
@testable import App

struct MenuBarComponentsTests {
    private func item(
        _ id: String, type: String = "item", x: Double = 0, members: [String] = [],
        drawing: Bool = true
    ) throws -> SketchybarItem {
        let object: [String: Any] = [
            "type": type, "bracket": members,
            "geometry": ["position": "right", "drawing": drawing ? "on" : "off"],
            "bounding_rects": ["display-1": ["origin": [x, 0], "size": [20, 35]]]
        ]
        let json = try #require(
            String(
                data: JSONSerialization.data(withJSONObject: object), encoding: .utf8))
        return try #require(SketchybarItem.parse(id: id, json: json))
    }

    @Test("CPU icon, readings and gap form one component using bracket membership")
    func brackets() throws {
        let items = try [
            item("cpu.text", x: 30), item("cpu.icon", x: 10), item("gap.cpu", x: 0),
            item("cpu.bracket", type: "bracket", members: ["cpu.icon", "cpu.text"])
        ]
        let groups = MenuBarComponents.discover(items)
        #expect(groups.count == 1)
        #expect(groups[0].members == ["gap.cpu", "cpu.icon", "cpu.text"])
        #expect(groups[0].brackets == ["cpu.bracket"])
    }

    @Test("workspaces form one group while the hidden updater stays out")
    func workspaces() throws {
        let items = try [
            item("space.1", type: "space"), item("space.2", type: "space", drawing: false),
            item("space_labels_updater", drawing: false)
        ]
        let groups = MenuBarComponents.discover(items)
        #expect(groups.count == 1)
        #expect(groups[0].id == "workspaces")
        #expect(groups[0].members.count == 2)
        #expect(groups[0].drawing["space.2"] == false)
    }

    @Test("new workspace members merge into a saved group without losing its settings")
    func dynamicMembership() throws {
        let old = MenuBarComponents.discover(try [item("space.1", type: "space")])
        var saved = BarConfiguration()
        saved.components = old
        saved.components[0].spacing = 17
        let updated = MenuBarComponents.discover(
            try [item("space.1", type: "space"), item("space.2", type: "space")])
        let merged = MenuBarComponents.merge(saved, discovered: updated, geometry: [:])
        #expect(merged.components[0].members == ["space.1", "space.2"])
        #expect(merged.components[0].spacing == 17)
    }
}
