import AppKit
import Testing
@testable import App
@testable import Macarchy

@MainActor
struct ComponentBoxLayoutTests {
    private func makeFixture() throws -> (item: SketchybarItem, url: URL) {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".png")
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 20, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
        var item = try #require(
            SketchybarItem.parse(
                id: "cpu.text",
                json: """
                    {"geometry":{"drawing":"on","position":"right","width":30},
                     "icon":{"value":"27.0%","drawing":"on","font":"Menlo:Bold:10","y_offset":6},
                     "label":{"value":"57.5°","drawing":"on","font":"Menlo:Bold:10","y_offset":-5},
                     "bounding_rects":{"display-1":{"origin":[100,0],"size":[30,35]}}}
                    """))
        item.background.imageURL = url
        return (item, url)
    }
    @Test("CPU readings fit their own native window without changing the component layout")
    func nativeReadingWindow() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.url) }
        var image = try #require(
            SketchybarItem.parse(
                id: "cpu.icon", json: "{\"geometry\":{\"drawing\":\"on\",\"position\":\"right\"}}"))
        image.background = fixture.item.background
        image.icon.drawing = false
        image.label.drawing = false
        image.background.imageScale = 1.024
        image.background.imagePaddingLeft = 0
        image.width = 30
        image.frame = CGRect(x: 100, y: 0, width: 30, height: 35)
        var reading = fixture.item
        reading.icon.value = "27.0%"
        reading.label.value = "57.5°"
        reading.background.imageURL = nil
        reading.width = 30
        reading.frame = CGRect(x: 130, y: 0, width: 30, height: 35)
        var component = BarComponent(
            id: "cpu", title: "CPU", side: "right", members: [image.id, reading.id])
        component.boxWidth = 60
        component.presentation = [
            image.id: ["align": "left", "width": "30", "padding_left": "0", "padding_right": "0"],
            reading.id: [
                "align": "left", "width": "30", "padding_left": "0", "padding_right": "0",
                "icon.width": "36", "icon.align": "right", "icon.padding_left": "-9",
                "icon.padding_right": "9",
                "label.width": "29", "label.align": "right", "label.padding_left": "-39",
                "label.padding_right": "39"
            ]
        ]
        let items = [image, reading]
        let before = ComponentGeometry(
            items: items, component: component, offsets: [image.id: 0, reading.id: 30])
        var configuration = BarConfiguration()
        configuration.components = [component]
        let repaired = ComponentBoxLayout.normalising(configuration, items: items)
        let box = try #require(repaired.components.first)
        #expect(box.presentation[image.id]?["width"] == "21.0")
        #expect(box.presentation[reading.id]?["width"] == "39.0")
        #expect(box.boxWidth == 60)
        #expect(ComponentBoxLayout.normalising(repaired, items: items) == repaired)
        let after = ComponentGeometry(
            items: items, component: box, offsets: [image.id: 0, reading.id: 21])
        for part in before.parts {
            let next = try #require(after.parts.first { $0.id == part.id })
            #expect(abs(next.frame.minX - part.frame.minX) < 0.001)
            #expect(next.frame.size == part.frame.size)
            let origin = part.member == image.id ? 0.0 : 21.0
            let slot = part.member == image.id ? 21.0 : 39.0
            #expect(next.frame.minX >= origin)
            #expect(next.frame.maxX <= origin + slot)
        }
        let native = BarCommands.nativePresentation(box.presentation)[reading.id] ?? [:]
        #expect(native["icon.padding_left"] == "36.0")
        #expect(native["label.padding_left"] == "35.0")
    }

}
