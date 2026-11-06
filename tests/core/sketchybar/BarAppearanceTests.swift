import Foundation
import Testing

@testable import Macarchy

/// Styling a component used to emit no commands at all unless the person had
/// added it themselves, and Apply reported success having changed nothing.
/// These pin the arguments that actually reach SketchyBar.
@Suite("Bar appearance commands")
struct BarAppearanceTests {
    private func builtIn() -> BarComponent {
        BarComponent(
            id: "gpu", title: "GPU", side: "right",
            members: ["gpu.icon", "gpu.label", "gap.gpu"],
            brackets: ["gpu.bracket"])
    }

    private func custom() -> BarComponent {
        var component = BarComponent(
            id: "macarchy.1", title: "Mine", side: "left", members: ["macarchy.1"])
        component.kind = "text"
        return component
    }

    private func arguments(_ component: BarComponent) -> [String] {
        var configuration = BarConfiguration()
        configuration.components = [component]
        return BarCommands.settings(configuration)
    }

    /// The bug: a widget that ships with the bar got no styling commands.
    @Test("a built-in component's colours reach its members")
    func builtInColours() {
        var component = builtIn()
        component.colour = "0xffef0a0a"
        let args = arguments(component)

        #expect(args.contains("label.color=0xffef0a0a"))
        #expect(args.contains("icon.color=0xffef0a0a"))
        // Fanned out over the real members, not the group id.
        #expect(args.contains("gpu.icon"))
        #expect(args.contains("gpu.label"))
    }

    /// Spacing members are layout, not content; colouring them does nothing.
    @Test("gap members are left out of the colour commands")
    func skipsGaps() {
        var component = builtIn()
        component.colour = "0xffef0a0a"
        let args = arguments(component)
        let colourIndexes = args.indices.filter { args[$0] == "icon.color=0xffef0a0a" }
        for index in colourIndexes {
            #expect(args[index - 1] != "gap.gpu")
        }
    }

    @Test("an icon colour overrides the label colour for the glyph only")
    func iconColourOverrides() {
        var component = builtIn()
        component.colour = "0xff00ff00"
        component.iconColour = "0xff0000ff"
        let args = arguments(component)
        #expect(args.contains("icon.color=0xff0000ff"))
        #expect(args.contains("label.color=0xff00ff00"))
        #expect(!args.contains("icon.color=0xff00ff00"))
    }

    /// SketchyBar draws a group's background on its bracket, not its leaves.
    @Test("a background lands on the bracket with its radius")
    func backgroundOnBracket() {
        var component = builtIn()
        component.backgroundColour = "0xff112233"
        component.cornerRadius = 6
        let args = arguments(component)

        guard let bracket = args.firstIndex(of: "gpu.bracket").map({ args[$0...] }) else {
            Issue.record("no bracket settings emitted")
            return
        }
        #expect(bracket.contains("background.drawing=on"))
        #expect(bracket.contains("background.color=0xff112233"))
        #expect(bracket.contains("background.corner_radius=6"))
    }

    @Test("an untouched native background is preserved")
    func backgroundClears() {
        let args = arguments(builtIn())
        #expect(!args.contains("background.drawing=off"))
        #expect(!args.contains { $0.hasPrefix("background.color=") })
    }

    /// A format was previously dead on the real bar.
    @Test("a custom component's label goes through its format")
    func customFormat() {
        var component = custom()
        component.text = "47"
        component.format = "{value}%"
        let args = arguments(component)
        #expect(args.contains("label=47%"))
        #expect(!args.contains("label=47"))
    }

    @Test("an empty rendered label turns label drawing off")
    func emptyLabel() {
        var component = custom()
        component.text = ""
        component.format = nil
        #expect(arguments(component).contains("label.drawing=off"))
    }

    /// Custom components carry their own fill; they have no bracket.
    @Test("a custom component's background lands on itself")
    func customBackground() {
        var component = custom()
        component.backgroundColour = "0xff445566"
        component.cornerRadius = 4
        let args = arguments(component)
        #expect(args.contains("background.color=0xff445566"))
        #expect(args.contains("background.corner_radius=4"))
        #expect(args.contains("background.drawing=on"))
    }
}
