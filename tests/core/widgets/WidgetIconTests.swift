import Foundation
import Testing

@testable import Macarchy

struct WidgetIconTests {
    @Test("hiding an icon survives saved styles, startup and reading updates")
    func hidden() throws {
        var manifest = WidgetManifest(id: "battery", name: "Battery")
        manifest.icon = "battery"
        var style = WidgetStyle()
        style.showIcon = false
        let saved = try JSONDecoder().decode(WidgetStyle.self, from: JSONEncoder().encode(style))
        var component = BarComponent(id: "test", title: "Test", side: "right", members: ["test"])
        component.widget = "battery"
        component.style = saved
        let look = WidgetLook(manifests: ["battery": manifest])
        #expect(look.arguments(for: component).contains("icon.drawing=off"))
        let instance = WidgetInstance(
            id: "test", manifest: manifest, directory: URL(fileURLWithPath: "/test"), settings: [:],
            visible: true, style: saved)
        var output = WidgetOutput()
        output.icon = "charging"
        let items = WidgetHost.items(instance, output: output, look: look)
        #expect(items.first?.properties.contains("icon.drawing=off") == true)
        #expect(items.first?.properties.contains("icon=charging") == false)
        manifest.style = WidgetStyle()
        manifest.style?.lines = 2
        let stacked = WidgetLook(manifests: ["battery": manifest]).arguments(for: component)
        #expect(stacked.contains("icon.drawing=off"))
        #expect(stacked.contains("width=0"))
    }
}
