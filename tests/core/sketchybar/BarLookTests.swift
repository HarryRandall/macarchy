import Foundation
import Testing

@testable import Macarchy

@Suite("The bar under the widgets")
struct BarLookTests {
    private var colours: BarLook.Colours {
        var colours = BarLook.Colours()
        colours.bar = "0xff101010"
        colours.text = "0xffeeeeee"
        return colours
    }

    @Test("startup sets up the owner's geometry, the theme's colours, the font and defaults")
    func startup() {
        let font = URL(fileURLWithPath: "/Applications/Macarchy.app/sketchybar-app-font.ttf")
        let arguments = BarLook.arguments(values: [:], colours: colours, font: font)
        #expect(
            arguments == [
                "--bar", "height=35", "position=top", "padding_left=10", "padding_right=10",
                "blur_radius=0", "corner_radius=0", "y_offset=0", "sticky=on",
                "color=0xff101010", "--load-font", font.path, "--default",
                "icon.color=0xffeeeeee", "label.color=0xffeeeeee"
            ])
    }

    @Test("saved geometry wins, and a missing font is left out")
    func savedGeometry() {
        let arguments = BarLook.arguments(
            values: ["SKETCHYBAR_HEIGHT": "28", "SKETCHYBAR_POSITION": "bottom"],
            colours: BarLook.Colours(), font: nil)
        #expect(arguments.contains("height=28") && arguments.contains("position=bottom"))
        #expect(arguments.contains("color=0x01000000"))
        #expect(!arguments.contains("--load-font"))
    }

    @Test("no theme gives a bar one step above transparent with white text")
    func defaults() {
        #expect(BarLook.Colours.theme(nil) == BarLook.Colours())
        #expect(BarLook.Colours().bar == "0x01000000" && BarLook.Colours().text == "0xffffffff")
    }

    @Test("recolouring repaints the bar and only the widget items on it")
    func recolour() {
        var bar = BarConfiguration.widgetDefault
        bar.components.append(
            BarComponent(id: "mine", title: "Mine", side: "right", members: ["mine"]))
        let arguments = BarLook.recolour(
            bar, colours: colours, existing: ["macarchy.clock", "mine"])
        #expect(
            arguments == [
                "--bar", "color=0xff101010", "--default", "icon.color=0xffeeeeee",
                "label.color=0xffeeeeee", "--set", "macarchy.clock", "icon.color=0xffeeeeee",
                "label.color=0xffeeeeee"
            ])
    }
}
