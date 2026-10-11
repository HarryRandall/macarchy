import CoreGraphics
import Foundation
import Testing
@testable import App
@testable import Macarchy

@MainActor
struct MenuBarPreviewTests {
    @Test("An untouched network preserves real overlapping member rectangles and visual order")
    func observedGeometry() throws {
        let icon = try item("network.icon", x: 960, width: 17)
        let text = try item("network.text", x: 968, width: 58)
        var configuration = BarConfiguration()
        configuration.components = [
            BarComponent(
                id: "network", title: "Network", side: "right",
                members: [icon.id, text.id])
        ]
        let layout = MenuBarLayout(
            items: [text, icon], configuration: configuration,
            applied: configuration, screenWidth: 1512)
        #expect(layout.memberFrames[icon.id] == icon.frame)
        #expect(layout.memberFrames[text.id] == text.frame)
        #expect(layout.frames["network"] == CGRect(x: 960, y: 0, width: 66, height: 35))
        var styled = configuration
        styled.components[0].colour = "0xff123456"
        #expect(MenuBarLayout.sameLayout(styled, configuration))
    }

    @Test("A padding edit changes measured width by the delta rather than adding padding twice")
    func draftGeometry() throws {
        let icon = try item("network.icon", x: 960, width: 17)
        let text = try item("network.text", x: 968, width: 58)
        var applied = BarConfiguration()
        applied.components = [
            BarComponent(
                id: "network", title: "Network", side: "right",
                members: [icon.id, text.id])
        ]
        var draft = applied
        draft.components[0].paddingOverride = applied.padding(for: applied.components[0]) + 3
        let layout = MenuBarLayout(
            items: [text, icon], configuration: draft,
            applied: applied, screenWidth: 1512)
        #expect(layout.frames["network"]?.width == 69)
        #expect(
            (layout.memberFrames[text.id]?.minX ?? 0)
                - (layout.memberFrames[icon.id]?.minX ?? 0) == 8)
    }

    @Test("Read-only observation refreshes a snapshot without replacing or saving a draft")
    func observationWithDraft() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let model = MenuBarModel(
            backend: backend.integration, log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        await model.hydrate()
        #expect(!model.hasChanges)
        #expect(model.draft.componentPadding == nil)
        #expect(model.draft.componentSpacing == nil)
        model.update("calendar") { $0.title = "My clock" }
        let draft = model.draft
        model.replaceSnapshot([], colour: nil)
        await model.refreshReadings()
        #expect(model.items.map(\.id) == ["calendar"])
        #expect(model.draft == draft)
        #expect(model.hasChanges)
        #expect(model.lastObservedAt != nil)
        #expect(model.observationError == nil)
        #expect(await backend.recordedWrites().isEmpty)
    }

    private func item(_ id: String, x: Double, width: Double) throws -> SketchybarItem {
        let raw: [String: Any] = [
            "geometry": ["position": "right", "drawing": "on", "width": width],
            "icon": ["value": "47.3%", "drawing": "on", "y_offset": 6],
            "label": ["value": "57.0°", "drawing": "on", "y_offset": -6],
            "bounding_rects": ["display-1": ["origin": [x, 0], "size": [width, 35]]]
        ]
        let data = try JSONSerialization.data(withJSONObject: raw)
        let json = try #require(String(data: data, encoding: .utf8))
        return try #require(SketchybarItem.parse(id: id, json: json))
    }
}

@MainActor
@Suite("Native text alignment")
struct NativeTextAlignmentTests {
    @Test func fixedRightAlignedStackKeepsReadingClearOfImage() throws {
        let json = """
            {"geometry":{"drawing":"on","position":"right","width":58},
             "icon":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","padding_left":0,"padding_right":0},
             "label":{"value":"0.0MB/s","drawing":"on","font":"Menlo:Bold:10","padding_left":-42,"padding_right":0},
             "bounding_rects":{"display-1":{"origin":[966,0],"size":[58,35]}}}
            """
        let item = try #require(SketchybarItem.parse(id: "network.text", json: json))
        let layout = SketchybarTextLayout(item)
        #expect(layout.iconX >= 14)
        #expect(abs(layout.labelX - layout.iconX) <= 2)
    }
}

extension MenuBarPreviewTests {
    @Test("Observation retries hydration after a transient initial query failure")
    func recoversHydration() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        await backend.failQueries(2)
        let model = MenuBarModel(
            backend: backend.integration, log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        await model.hydrate()
        #expect(model.error != nil)
        await model.refreshReadings()
        #expect(model.error == nil)
        #expect(model.draft.components.count == 1)
        #expect(!model.hasChanges)
        #expect(await backend.recordedWrites().isEmpty)
    }
}

@Suite("Component preview fitting")
struct ComponentPreviewFitTests {
    @Test func largeContentAlwaysStaysInsideCanvas() {
        let content = CGSize(width: 900, height: 140)
        let available = CGSize(width: 560, height: 94)
        let scale = ComponentPreviewFit.scale(content: content, available: available)
        #expect(content.width * scale <= available.width - 24)
        #expect(content.height * scale <= available.height - 12)
        #expect(scale < 1)
    }

    @Test func smallContentStopsAtTwoTimes() {
        #expect(
            ComponentPreviewFit.scale(
                content: CGSize(width: 60, height: 35),
                available: CGSize(width: 560, height: 94)) == 2)
    }
}

extension MenuBarPreviewTests {
    @Test("A fixed group width preserves overlapping member positions")
    func explicitGroupWidth() throws {
        let icon = try item("network.icon", x: 960, width: 17)
        let text = try item("network.text", x: 968, width: 58)
        var applied = BarConfiguration()
        applied.components = [
            BarComponent(
                id: "network", title: "Network", side: "right", members: [icon.id, text.id])
        ]
        var draft = applied
        draft.components[0].boxWidth = 100
        let reservation = try #require(
            ComponentSizing.reservation(
                items: [icon, text], component: draft.components[0], width: 100))
        #expect(reservation.id == text.id)
        #expect(reservation.width == 92)
        draft.components[0].presentation[text.id] = ["width": "92"]
        let layout = MenuBarLayout(
            items: [icon, text], configuration: draft, applied: applied, screenWidth: 1512)
        #expect(layout.frames["network"]?.width == 100)
        #expect(
            (layout.memberFrames[text.id]?.minX ?? 0) - (layout.memberFrames[icon.id]?.minX ?? 0)
                == 8)
        #expect(BarCommands.changes(draft, from: applied, baseline: [:]).contains("width=92"))
    }

    @Test("Fit widest sample measures readings rather than existing empty reserve")
    func fitSamples() throws {
        let text = try item("cpu.text", x: 960, width: 200)
        let component = BarComponent(id: "cpu", title: "CPU", side: "right", members: [text.id])
        let width = ComponentSizing.requiredWidth(items: [text], component: component)
        #expect(width >= SketchybarFont(text.icon.font).width(text.icon.value))
        #expect(width < 200)
    }
}

extension MenuBarPreviewTests {
    @Test("Component edits can read the draft without overlapping a write")
    func draftReadsDuringEdit() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let model = MenuBarModel(
            backend: backend.integration, log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        await model.hydrate()
        let original = model.draft
        model.update("calendar") { target in
            let observed = model.draft.components.first { $0.id == target.id }
            #expect(observed == original.components.first)
            target.boxWidth = 104
            target.presentation[target.id] = ["width": "104"]
        }
        #expect(model.draft.components.first?.boxWidth == 104)
        #expect(model.canUndo)
        #expect(await backend.recordedWrites().isEmpty)
        model.undoLast()
        #expect(model.draft == original)
        #expect(!model.canUndo)
    }
}
