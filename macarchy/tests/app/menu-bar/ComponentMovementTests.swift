import AppKit
import Foundation
import Testing
@testable import App
@testable import Macarchy

@MainActor
struct ComponentMovementTests {
    private struct Fixture {
        let item: SketchybarItem
        let component: BarComponent
        let url: URL
    }

    private func fixture() throws -> Fixture {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".png")
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 20,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
        var item = try #require(
            SketchybarItem.parse(
                id: "network.text",
                json: """
                    {"geometry":{"drawing":"on","position":"right","width":90},
                     "icon":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","y_offset":5},
                     "label":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","padding_left":-42,"y_offset":-4},
                     "bounding_rects":{"display-1":{"origin":[20,0],"size":[90,35]}}}
                    """))
        item.background.imageURL = url
        item.background.imageScale = 1
        item.background.imagePaddingLeft = 8
        var component = BarComponent(
            id: "network", title: "Network", side: "right", members: [item.id])
        component.boxWidth = 90
        return Fixture(item: item, component: component, url: url)
    }

    @Test("The icon moves left independently without changing the readings or box")
    func imageMovement() throws {
        let fixture = try fixture()
        let item = fixture.item
        let component = fixture.component
        let url = fixture.url
        defer { try? FileManager.default.removeItem(at: url) }
        let before = ComponentGeometry(items: [item], component: component)
        let moved = ComponentMovement.moving(
            items: [item], component: component, ids: [item.id + ":image"],
            delta: CGSize(width: -4, height: 2))
        let after = ComponentGeometry(items: [item], component: moved)
        for part in before.parts {
            let next = try #require(after.parts.first { $0.id == part.id })
            #expect(next.frame.minX == part.frame.minX + (part.layer == "image" ? -4 : 0))
            #expect(next.frame.minY == part.frame.minY + (part.layer == "image" ? 2 : 0))
        }
        #expect(moved.boxWidth == component.boxWidth)
    }

    @Test("Selecting all parts translates them equally, keeping their spacing and box")
    func groupMovement() throws {
        let fixture = try fixture()
        let item = fixture.item
        let component = fixture.component
        let url = fixture.url
        defer { try? FileManager.default.removeItem(at: url) }
        let before = ComponentGeometry(items: [item], component: component)
        let moved = ComponentMovement.moving(
            items: [item], component: component, ids: Set(before.parts.map(\.id)),
            delta: CGSize(width: -3, height: -2))
        let after = ComponentGeometry(items: [item], component: moved)
        for part in before.parts {
            let next = try #require(after.parts.first { $0.id == part.id })
            #expect(abs(next.frame.minX - part.frame.minX + 3) <= 0.5)
            #expect(next.frame.minY == part.frame.minY - 2)
        }
        #expect(moved.boxWidth == component.boxWidth)
        var config = BarConfiguration()
        config.components = [moved]
        try config.validate()
        let commands = BarCommands.settings(config)
        #expect(commands.contains("background.image.padding_left=5.0"))
        #expect(commands.contains("background.image.y_offset=2.0"))
        #expect(!commands.contains(where: { $0.hasPrefix("label=") || $0.hasPrefix("script=") }))
    }

    @Test("Resizing from the left keeps the right edge of both text and images fixed")
    func leftResize() throws {
        let fixture = try fixture()
        let item = fixture.item
        let component = fixture.component
        let url = fixture.url
        defer { try? FileManager.default.removeItem(at: url) }
        for layer in ["image", "icon", "label"] {
            var edits =
                layer == "image"
                ? ["background.image.scale": "1.5"] : ComponentGeometry.positionedText(item)
            if layer != "image" { edits[layer + ".font"] = "Menlo:Bold:15" }
            let anchored = ComponentMovement.anchoringRightEdge(
                edits, item: item, component: component, layer: layer)
            var resized = component
            resized.presentation[item.id] = anchored
            let before = try #require(
                ComponentGeometry(items: [item], component: component).parts.first {
                    $0.layer == layer
                })
            let after = try #require(
                ComponentGeometry(items: [item], component: resized).parts.first {
                    $0.layer == layer
                })
            #expect(abs(after.frame.maxX - before.frame.maxX) <= 0.5)
            #expect(after.frame.width > before.frame.width)
        }
    }

    @Test("Box edges resize independently while all content stays fixed on screen")
    func boxEdges() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.url) }
        let items = [fixture.item]
        for leading in [true, false] {
            var component = fixture.component
            var boxLeft = 0.0
            let original = ComponentGeometry(items: items, component: component)
            for proposed in [110.0, 130, 75, 10, 2000, 90] {
                let previousWidth = try #require(component.boxWidth)
                let resized = ComponentSizing.resizing(
                    items: items, component: component, currentWidth: previousWidth,
                    width: proposed, leading: leading)
                let width = try #require(resized.boxWidth)
                if leading { boxLeft -= width - previousWidth }
                let after = ComponentGeometry(items: items, component: resized)
                for part in original.parts {
                    let next = try #require(after.parts.first { $0.id == part.id })
                    #expect(abs(boxLeft + next.frame.minX - part.frame.minX) <= 0.5)
                    #expect(next.frame.minY == part.frame.minY)
                    #expect(next.frame.size == part.frame.size)
                }
                #expect(width == min(max(proposed, 24), 1000))
                var config = BarConfiguration()
                config.components = [resized]
                try config.validate()
                component = resized
            }
        }
    }

    @Test("Live readings keep the longest slot and unit position after fitting and moving")
    func reservedReadingSlots() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.url) }
        var item = fixture.item
        item.icon.value = "2.6%"
        item.label.value = "66.1°"
        var component = fixture.component
        component.id = "gpu"
        let fitted = ComponentSizing.fitting(
            items: [item], component: component, offsets: [item.id: 0], padding: 0, height: 35)
        let live = ComponentGeometry(items: [item], component: fitted)
        let longest = ComponentGeometry(items: [item], component: fitted, sample: "Widest")
        for layer in ["icon", "label"] {
            let current = try #require(live.parts.first { $0.layer == layer })
            let worst = try #require(longest.parts.first { $0.layer == layer })
            #expect(current.frame == worst.frame)
            let currentItem = try #require(live.items.first)
            let worstItem = try #require(longest.items.first)
            let currentText = layer == "icon" ? currentItem.icon : currentItem.label
            let worstText = layer == "icon" ? worstItem.icon : worstItem.label
            let currentLayout = SketchybarTextLayout(currentItem)
            let worstLayout = SketchybarTextLayout(worstItem)
            let currentX = layer == "icon" ? currentLayout.iconX : currentLayout.labelX
            let worstX = layer == "icon" ? worstLayout.iconX : worstLayout.labelX
            #expect(
                currentX + SketchybarFont(currentText.font).width(currentText.value)
                    == worstX + SketchybarFont(worstText.font).width(worstText.value))
        }
        #expect(live.contentBounds.maxX <= (fitted.boxWidth ?? 0))
        let moved = ComponentMovement.moving(
            items: [item], component: fitted, ids: Set(live.parts.map(\.id)),
            delta: CGSize(width: 5, height: 0))
        let after = ComponentGeometry(items: [item], component: moved)
        for part in live.parts {
            let next = try #require(after.parts.first { $0.id == part.id })
            #expect(abs(next.frame.minX - part.frame.minX - 5) <= 0.5)
            #expect(next.frame.size == part.frame.size)
        }
        var config = BarConfiguration()
        config.components = [fitted]
        try config.validate()
        #expect(
            !BarCommands.settings(config).contains {
                $0.hasPrefix("label=") || $0.hasPrefix("icon=")
            })
    }

    @Test("Fit restores moved image content, including its negative left and vertical offset")
    func fitMovedImage() throws {
        let fixture = try fixture()
        let item = fixture.item
        let component = fixture.component
        let url = fixture.url
        defer { try? FileManager.default.removeItem(at: url) }
        let moved = ComponentMovement.moving(
            items: [item], component: component, ids: [item.id + ":image"],
            delta: CGSize(width: -20, height: -30))
        let fitted = ComponentSizing.fitting(
            items: [item], component: moved, offsets: [item.id: 0], padding: 0, height: 35)
        let geometry = ComponentGeometry(items: [item], component: fitted, sample: "Widest")
        #expect(geometry.contentBounds.minX >= 0)
        #expect(geometry.contentBounds.minY >= 0)
        #expect(geometry.contentBounds.maxY <= 35)
        #expect(geometry.contentBounds.maxX <= (fitted.boxWidth ?? 0))
    }
}

extension ComponentMovementTests {
    @Test("Zero gap boxes remove native overlap padding without moving authored content")
    func nativeBoxSpacing() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.url) }
        var image = try #require(
            SketchybarItem.parse(
                id: "gpu.icon", json: "{\"geometry\":{\"drawing\":\"on\",\"position\":\"right\"}}"))
        image.background = fixture.item.background
        image.icon.drawing = false
        image.label.drawing = false
        image.width = 30
        image.frame = CGRect(x: 100, y: 0, width: 30, height: 35)
        var reading = try #require(
            SketchybarItem.parse(
                id: "gpu.text",
                json: """
                    {"geometry":{"drawing":"on","position":"right","width":39,"padding_right":9},
                     "icon":{"value":"2.6%","drawing":"on","font":"Menlo:Bold:10","y_offset":5},
                     "label":{"value":"66.1°","drawing":"on","font":"Menlo:Bold:10","padding_left":-24,"y_offset":-4}}
                    """))
        reading.background.imageURL = nil
        reading.width = 39
        reading.frame = CGRect(x: 121, y: 0, width: 39, height: 35)
        var component = BarComponent(
            id: "gpu", title: "GPU", side: "right", members: [image.id, reading.id])
        component.boxWidth = 60
        component.spacingOverride = 0
        component.paddingOverride = 0
        var configuration = BarConfiguration()
        configuration.components = [component]
        let items = [image, reading]
        let before = ComponentGeometry(items: items, component: component)
        let normalised = ComponentBoxLayout.normalising(configuration, items: items)
        let box = try #require(normalised.components.first)
        #expect(box.hasBoxLayout)
        try checkPadding(normalised, items: items, imageID: image.id, readingID: reading.id)
        #expect(ComponentBoxLayout.normalising(normalised, items: items) == normalised)
        let after = ComponentGeometry(
            items: items, component: box, offsets: [image.id: 0, reading.id: 30])
        for part in before.parts {
            let next = try #require(after.parts.first { $0.id == part.id })
            #expect(abs(next.frame.minX - part.frame.minX) <= 0.5)
        }
        #expect(box.presentation[reading.id]?["width"] == "30.0")
        let resized = ComponentSizing.resizing(
            items: items, component: box, currentWidth: 60, width: 80, leading: false)
        #expect(resized.presentation[reading.id]?["width"] == "50.0")
        let layout = MenuBarLayout(
            items: items, configuration: normalised, applied: normalised, screenWidth: 1500)
        #expect(layout.memberFrames[reading.id]?.minX == (layout.frames[box.id]?.minX ?? 0) + 30)
        #expect(layout.frames[box.id]?.width == 60)
    }

    private func checkPadding(
        _ normalised: BarConfiguration, items: [SketchybarItem], imageID: String, readingID: String
    ) throws {
        #expect(normalised.padding(for: normalised.components[0]) == 0)
        var padded = normalised
        padded.componentPadding = 5
        padded.components[0].paddingOverride = nil
        let shifted = ComponentBoxLayout.applyingPaddingChange(
            padded, from: normalised, items: items)
        let paddedGeometry = ComponentGeometry(
            items: items, component: shifted.components[0], offsets: [imageID: 0, readingID: 30])
        for part in ComponentGeometry(
            items: items, component: normalised.components[0], offsets: [imageID: 0, readingID: 30]
        ).parts {
            let next = try #require(paddedGeometry.parts.first { $0.id == part.id })
            #expect(abs(next.frame.minX - part.frame.minX - 5) <= 0.5)
        }
    }
}
