import Foundation
import Testing

@testable import Macarchy

@Suite("Spaces widget")
struct SpacesWidgetTests {
    private let spaces = Data(
        """
        [{"index":2,"display":1,"is-visible":false},{"index":1,"display":1,"is-visible":true},
         {"index":3,"display":2,"is-visible":true}]
        """.utf8)
    private let windows = Data(
        """
        [{"id":5,"app":"Code","space":1,"display":1,"role":"AXWindow","subrole":"AXStandardWindow",
          "frame":{"x":900,"y":0},"has-ax-reference":true,"is-minimized":false,"is-hidden":false},
         {"id":4,"app":"Safari","space":1,"display":1,"role":"AXWindow","subrole":"AXStandardWindow",
          "frame":{"x":0,"y":0},"has-ax-reference":true},
         {"id":6,"app":"Notes","space":1,"display":1,"role":"AXWindow","subrole":"AXStandardWindow",
          "frame":{"x":0,"y":0},"is-minimized":true},
         {"id":7,"app":"Finder","space":2,"display":1,"role":"AXWindow","subrole":"AXDialog",
          "frame":{"x":0,"y":0}}]
        """.utf8)

    private var reading: SpacesReading {
        get throws { try #require(SpacesReading.parse(spaces: spaces, windows: windows)) }
    }

    private let icons = AppIcons(
        exact: ["Safari": ":safari:", "Code": ":code:"], prefixes: [["Adobe", ":adobe:"]])

    @Test("Spaces come in order with the apps a person would count, left to right")
    func parse() throws {
        let reading = try reading
        #expect(reading.spaces.map(\.index) == [1, 2, 3])
        #expect(reading.spaces[0].apps == ["Safari", "Code"])
        #expect(reading.spaces[1].apps.isEmpty && reading.spaces[2].display == 2)
        #expect(SpacesReading.parse(spaces: Data("nope".utf8), windows: nil) == nil)
    }

    @Test("a Space about to be shown becomes the current one on its display only")
    func showing() throws {
        let shown = try reading.showing(2)
        #expect(shown.spaces.map(\.visible) == [false, true, true])
        #expect(try reading.showing(9) == reading)
    }

    @Test("apps get their glyph, by name, then by prefix, then the default")
    func glyphs() throws {
        #expect(icons.glyph(for: "Safari") == ":safari:")
        #expect(icons.glyph(for: "Adobe Photoshop 2026") == ":adobe:")
        #expect(icons.glyph(for: "Mystery") == ":default:")
        let shipped = AppIcons.load(
            from: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appending(path: "../../../resources/widgets/spaces"))
        #expect(shipped.glyph(for: "Safari") == ":safari:" && shipped.exact.count > 500)
    }

    @Test("the current Space is boxed in its colour, and missing Spaces are hidden")
    func current() throws {
        let output = ReadingOutputs.spaces(try reading, icons: icons, slots: 4, settings: [:])
        let items = try #require(output.items)
        #expect(items.count == 4)
        #expect(items[0].icon == "1" && items[0].label == "  :safari: :code:")
        #expect(items[0].colour == "accent" && items[0].background == "accent")
        #expect(items[0].border == "accent")
        #expect(items[1].label == " —" && items[1].colour == "text" && items[1].border == nil)
        #expect(items[2].display == 2 && items[3].drawing == false)
        #expect(output.border == nil)
    }

    @Test("settings change the boxes, what shows, names and how many apps")
    func settings() throws {
        let reading = try reading
        let every = try #require(
            ReadingOutputs.spaces(
                reading, icons: icons, slots: 3, settings: ["design": .text("every")]
            ).items)
        #expect(every[1].border == ReadingOutputs.spaceOutline)
        let together = ReadingOutputs.spaces(
            reading, icons: icons, slots: 3, settings: ["design": .text("together")])
        #expect(together.border == ReadingOutputs.spaceOutline)
        #expect(together.items?[0].background == "accent" && together.items?[0].border == nil)
        let named = try #require(
            ReadingOutputs.spaces(
                reading, icons: icons, slots: 3,
                settings: [
                    "names": .text("Web, , Chat"), "show": .text("numbers"),
                    "hideEmpty": .bool(true), "activeColour": .text("#ff0000")
                ]
            ).items)
        #expect(named.map(\.icon) == ["Web", nil, "Chat"])
        #expect(named[0].label?.isEmpty == true && named[0].colour == "#ff0000")
        #expect(named[1].drawing == false)
        #expect(
            ReadingOutputs.strip(["Safari", "Code", "Safari"], icons: icons, most: 2)
                == ":safari: :code: +1")
    }

    @Test("a row is an item per slot and a box, and clicking a Space goes straight there")
    func layout() throws {
        var manifest = WidgetManifest(id: "spaces", name: "Spaces")
        manifest.source = "spaces"
        manifest.style = WidgetStyle()
        manifest.style?.row = 3
        let look = WidgetLook(manifests: ["spaces": manifest])
        var component = BarComponent(
            id: "macarchy.spaces", title: "Spaces", side: "left", members: ["macarchy.spaces"])
        component.widget = "spaces"
        var configuration = BarConfiguration()
        configuration.components = [component]
        let normalised = look.normalised(configuration)
        #expect(
            normalised.components[0].members == [
                "macarchy.spaces.1", "macarchy.spaces.2", "macarchy.spaces.3"
            ])
        #expect(normalised.components[0].brackets == ["macarchy.spaces.box"])
        try normalised.validate()
        let arguments = look.arguments(for: normalised.components[0])
        #expect(arguments.contains { $0.hasPrefix("click_script=") && $0.hasSuffix(" space 3") })
        #expect(arguments.contains("label.font=sketchybar-app-font:Regular:13.0"))
        let subscribe = try #require(arguments.firstIndex(of: "--subscribe"))
        #expect(
            Array(arguments[subscribe...].prefix(3))
                == ["--subscribe", "macarchy.spaces.1", "space_windows_change"])
        #expect(arguments.contains { $0.hasSuffix("widget trigger windows_changed") })
    }

    @Test("each item shows its entry, tinted when current, and the row's box follows the output")
    func items() throws {
        var manifest = WidgetManifest(id: "spaces", name: "Spaces")
        manifest.style = WidgetStyle()
        manifest.style?.row = 2
        let instance = WidgetInstance(
            id: "macarchy.spaces", manifest: manifest, directory: URL(fileURLWithPath: "/"),
            settings: [:], visible: true)
        let output = ReadingOutputs.spaces(
            try reading, icons: icons, slots: 2, settings: ["design": .text("together")])
        let items = WidgetHost.items(
            instance, output: output, look: WidgetLook(accent: "0xffbfa75d", text: "0xffdddddd"))
        #expect(
            items.map(\.item) == ["macarchy.spaces.1", "macarchy.spaces.2", "macarchy.spaces.box"])
        #expect(items[0].properties.contains("background.color=0x1abfa75d"))
        #expect(items[0].properties.contains("label.color=0xffbfa75d"))
        #expect(items[1].properties.contains("label.color=0xffdddddd"))
        #expect(items[1].properties.contains("background.drawing=off"))
        #expect(items[2].properties.contains("drawing=on"))
        #expect(items[2].properties.contains("background.border_color=0x33ffffff"))
        let empty = WidgetHost.items(instance, output: nil, look: WidgetLook())
        #expect(empty[0].properties == ["drawing=off"])
    }
}
