import Foundation
import Testing
import Macarchy

@testable import App

@MainActor
@Suite("Spacer editor")
struct ComponentSpacerTests {
    @Test("spacers resize below the normal component minimum without native parts")
    func narrowSpacer() throws {
        let template = try #require(ComponentTemplate.all.first { $0.id == "spacer" })
        var component = Macarchy.BarComponent(
            id: "space", title: "Spacer", side: "right", members: ["space"])
        template.apply(to: &component)
        let resized = ComponentSizing.resizing(
            items: [], component: component, currentWidth: 20, width: 7, leading: true)
        #expect(resized.boxWidth == 7)
        #expect(resized.customWidth == 7)
        #expect(resized.presentation.isEmpty)
        #expect(MenuBarLayout.customWidth(resized) == 7)
    }
    @Test("adding a spacer inserts it after the selected component without applying")
    func insertion() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let backend = MenuBarTestBackend()
        let model = MenuBarModel(
            backend: backend.integration, log: CommandLog(),
            configurationStore: BarConfigurationStore(directory: root))
        await model.hydrate()
        let template = try #require(ComponentTemplate.all.first { $0.id == "spacer" })
        model.selected = "calendar"
        model.add(from: template)
        #expect(model.draft.components.map(\.title) == ["Clock", "Spacer"])
        #expect(model.selectedComponent?.kind == "spacer")
        #expect(model.selectedComponent?.side == "right")
        #expect(await backend.recordedWrites().isEmpty)
    }

}
