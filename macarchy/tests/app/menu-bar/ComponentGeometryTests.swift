import AppKit
import Foundation
import Testing
@testable import App
@testable import Macarchy

@MainActor
struct ComponentGeometryTests {
    private func item(
        _ id: String = "network.text", x: Double = 20, width: Double = 58
    ) throws -> SketchybarItem {
        try #require(
            SketchybarItem.parse(
                id: id,
                json: """
                    {"geometry":{"drawing":"on","position":"right","width":\(width)},
                     "icon":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","y_offset":5},
                     "label":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","padding_left":-42,"y_offset":-4},
                     "bounding_rects":{"display-1":{"origin":[\(x),0],"size":[\(width),35]}}}
                    """))
    }

    @Test("Independent native text positions preserve both row starts")
    func positioning() throws {
        let item = try item()
        var component = BarComponent(
            id: "network", title: "Network", side: "right", members: [item.id])
        let before = SketchybarTextLayout(item)
        component.presentation[item.id] = ComponentGeometry.positionedText(item)
        let after = SketchybarTextLayout(item.presenting(component))
        #expect(abs(after.iconX - before.iconX) <= 0.5)
        #expect(abs(after.labelX - before.labelX) <= 0.5)
        let live = ComponentGeometry(items: [item], component: component)
        let widest = ComponentGeometry(items: [item], component: component, sample: "Widest")
        #expect(live.parts[0].frame.minX == widest.parts[0].frame.minX)
        #expect(live.parts[1].frame.minX == widest.parts[1].frame.minX)
        #expect(widest.parts[0].frame.width > live.parts[0].frame.width)
        var config = BarConfiguration()
        config.components = [component]
        try config.validate()
        let commands = BarCommands.changes(config, from: BarConfiguration(), baseline: [:])
        #expect(commands.contains("icon.width=0"))
        #expect(commands.contains("label.width=0"))
        #expect(!commands.contains(where: { $0.hasPrefix("script=") || $0.hasPrefix("label=") }))
    }

    @Test("Fit includes an image, negative left extent and longest readings")
    func fitsBothEdges() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 30,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
        var icon = try item("network.icon", x: 10, width: 17)
        icon.icon.drawing = false
        icon.label.drawing = false
        icon.background.imageURL = url
        icon.background.imageScale = 2
        let text = try item(x: 18)
        var component = BarComponent(
            id: "network", title: "Network", side: "right", members: [icon.id, text.id])
        component.presentation[text.id] = ["icon.padding_left": "-30"]
        let offsets = [icon.id: 0.0, text.id: 3.0]
        let fitted = ComponentSizing.fitting(
            items: [icon, text], component: component, offsets: offsets, padding: 0, height: 35)
        let shifted = offsets
        for state in ["Now", "Idle", "Busy", "Widest", "Unavailable"] {
            let geometry = ComponentGeometry(
                items: [icon, text], component: fitted, sample: state, offsets: shifted)
            #expect(geometry.contentBounds.minX >= 0)
            #expect(geometry.contentBounds.maxX <= (fitted.boxWidth ?? 0))
            #expect(geometry.contentBounds.minY >= 0)
            #expect(geometry.contentBounds.maxY <= 35)
        }
        let refitted = ComponentSizing.fitting(
            items: [icon, text], component: fitted,
            offsets: offsets, padding: 0, height: 35)
        #expect(refitted.boxWidth == fitted.boxWidth)
        #expect(refitted.paddingOverride == component.paddingOverride)
        #expect(fitted.presentation[text.id]?["label"] == nil)
        #expect(fitted.presentationDefaults[text.id]?["icon.width"] == "dynamic")
    }

    @Test("Hidden native items never determine the fitted box or reservation")
    func hiddenItems() throws {
        let shown = try item()
        let hidden = try item("worker", x: -9999, width: 600)
        let component = BarComponent(
            id: "network", title: "Network", side: "right", members: [shown.id, hidden.id])
        #expect(
            ComponentSizing.requiredWidth(items: [shown, hidden], component: component)
                == ComponentSizing.requiredWidth(items: [shown], component: component))
        #expect(
            ComponentSizing.reservation(items: [shown, hidden], component: component, width: 90)?.id
                == shown.id)
    }

    @Test("Text that is too tall is fitted inside the bar height")
    func verticalFit() throws {
        let item = try item()
        var component = BarComponent(
            id: "network", title: "Network", side: "right", members: [item.id])
        component.presentation[item.id] = ["icon.font": "Menlo:Bold:40", "icon.y_offset": "20"]
        let fitted = ComponentSizing.fitting(
            items: [item], component: component, offsets: [item.id: 0], padding: 0, height: 35)
        let geometry = ComponentGeometry(items: [item], component: fitted, sample: "Widest")
        #expect(geometry.contentBounds.minY >= 0)
        #expect(geometry.contentBounds.maxY <= 35)
    }

    @Test("Slow scaled drags accumulate rather than losing subpoint movement")
    func slowDrag() {
        var consumed = CGSize.zero
        for x in stride(from: 0.2, through: 12.0, by: 0.2) {
            let delta = ComponentPreviewFit.dragStep(
                translation: CGSize(width: x, height: 0), consumed: consumed, scale: 2)
            consumed.width += delta.width * 2
        }
        #expect(abs(consumed.width - 12) < 0.01)
    }

    @Test("Direct positioning reserves the observed width of a dynamic item")
    func dynamicReservation() throws {
        var item = try item()
        item.width = 0
        let values = ComponentGeometry.positionedText(item)
        #expect(values["width"] == "58.0")
    }

    @Test("One drag can be undone in one action")
    func undoInteraction() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let model = MenuBarModel(
            backend: backend.integration, log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        await model.hydrate()
        let before = model.draft
        model.beginInteraction()
        for width in [80.0, 90, 100] { model.update("calendar") { $0.boxWidth = width } }
        model.endInteraction()
        model.undoLast()
        #expect(model.draft == before)
        #expect(!model.canUndo)
        #expect(await backend.recordedWrites().isEmpty)
    }
}

extension ComponentGeometryTests {
    @Test("Formatting spaces do not push a right-aligned memory reading out of its box")
    func paddedReading() throws {
        let item = try #require(
            SketchybarItem.parse(
                id: "ram.text",
                json: """
                    {"geometry":{"drawing":"on","position":"right","width":40},
                     "icon":{"drawing":"off"},
                     "label":{"value":" 7.0G","drawing":"on","font":"Menlo:Bold:10","width":30,"align":"right"},
                     "bounding_rects":{"display-1":{"origin":[0,0],"size":[40,35]}}}
                    """))
        let component = BarComponent(id: "ram", title: "Memory", side: "right", members: [item.id])
        let geometry = ComponentGeometry(items: [item], component: component)
        let row = try #require(geometry.parts.first)
        let presented = try #require(geometry.items.first)
        #expect(presented.label.displayValue == "7.0G")
        #expect(presented.label.value == " 7.0G")
        let font = SketchybarFont(presented.label.font)
        let x = SketchybarTextLayout(presented).labelX
        #expect(x + font.width(presented.label.displayValue) <= row.frame.maxX)
        #expect(row.frame.width == 30)
        var unaligned = presented.label
        unaligned.alignment = "left"
        #expect(unaligned.displayValue == " 7.0G")
    }
}
