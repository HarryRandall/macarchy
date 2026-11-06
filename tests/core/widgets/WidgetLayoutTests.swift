import Foundation
import Testing

@testable import Macarchy

struct WidgetLayoutTests {
    private func widget(click: WidgetClick? = nil, style: WidgetStyle? = nil) -> WidgetManifest {
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        manifest.icon = "􀧞"
        manifest.click = click
        manifest.style = style
        return manifest
    }

    private func instance(_ id: String = "macarchy.clock") -> BarComponent {
        var component = BarComponent(id: id, title: "Clock", side: "right", members: [id])
        component.widget = "clock"
        return component
    }

    @Test("global layout reaches startup and live Apply for every widget shape")
    func globalLayout() throws {
        var stacked = WidgetStyle()
        stacked.lines = 2
        var row = WidgetStyle()
        row.row = 3
        let manifests = [
            "clock": widget(), "stack": widget(style: stacked), "row": widget(style: row)
        ]
        var components = [instance("single"), instance("stacked"), instance("row")]
        components[1].widget = "stack"
        components[2].widget = "row"
        let look = WidgetLook(manifests: manifests)
        var before = BarConfiguration()
        before.components = components
        before = look.normalised(before)
        var after = before
        after.widgetGap = 12
        after.widgetInset = 14
        after.widgetHeight = 30
        after.geometry["y_offset"] = "8"
        let data = try JSONEncoder().encode(after)
        let saved = try JSONDecoder().decode(BarConfiguration.self, from: data)
        #expect(saved == after)
        let startup = BarCommands.settings(saved, startup: true, widgets: look)
        let live = BarCommands.changes(saved, from: before, baseline: [:], widgets: look)
        for arguments in [startup, live] {
            #expect(arguments.contains("y_offset=8"))
            #expect(arguments.contains("padding_left=12"))
            #expect(arguments.contains("width=12"))
            #expect(arguments.filter { $0 == "background.height=30" }.count == 2)
            #expect(arguments.contains("icon.padding_left=14"))
            #expect(arguments.contains("label.padding_right=14"))
        }
        let rowBefore = look.arguments(for: before.components[2])
        let rowAfter = look.configured(after).arguments(for: after.components[2])
        #expect(rowAfter == rowBefore)
        var component = instance()
        component.style = WidgetStyle()
        component.style?.paddingLeft = 3
        #expect(look.configured(after).arguments(for: component).contains("icon.padding_left=3"))
        after.widgetGap = -1
        #expect(throws: ConfigurationError.self) { try after.validate() }
    }

}
