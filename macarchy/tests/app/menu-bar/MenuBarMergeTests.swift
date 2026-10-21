import Foundation
import Testing

@testable import App
@testable import Macarchy

/// Hydrating rebuilds the draft from what is live on the bar. It used to copy
/// the authored fields across one by one, so each newly added field was
/// silently dropped the next time the app refreshed.
@Suite("Merge keeps authored fields")
struct MenuBarMergeTests {
    private func stored() -> BarComponent {
        var component = BarComponent(
            id: "gpu", title: "My GPU", side: "left", members: ["old"], brackets: [])
        component.colour = "0xffef0a0a"
        component.iconColour = "0xff00ff00"
        component.backgroundColour = "0xff112233"
        component.cornerRadius = 6
        component.format = "{value}%"
        component.sampleValues = ["0", "100"]
        component.paddingOverride = 3
        return component
    }

    private func discovered() -> BarComponent {
        BarComponent(
            id: "gpu", title: "GPU", side: "right",
            members: ["gpu.icon", "gpu.label"], brackets: ["gpu.bracket"])
    }

    @Test("every authored field survives a hydrate")
    func keepsAuthoredFields() {
        var saved = BarConfiguration()
        saved.components = [stored()]
        let merged = MenuBarComponents.merge(
            saved, discovered: [discovered()], geometry: [:])

        let gpu = merged.components.first { $0.id == "gpu" }
        #expect(gpu?.title == "My GPU")
        #expect(gpu?.side == "left")
        #expect(gpu?.colour == "0xffef0a0a")
        #expect(gpu?.iconColour == "0xff00ff00")
        #expect(gpu?.backgroundColour == "0xff112233")
        #expect(gpu?.cornerRadius == 6)
        #expect(gpu?.format == "{value}%")
        #expect(gpu?.sampleValues == ["0", "100"])
        #expect(gpu?.paddingOverride == 3)
    }

    /// Discovery still owns what it can see: the real members and brackets.
    @Test("live membership replaces what was saved")
    func takesLiveMembership() {
        var saved = BarConfiguration()
        saved.components = [stored()]
        let merged = MenuBarComponents.merge(
            saved, discovered: [discovered()], geometry: [:])

        let gpu = merged.components.first { $0.id == "gpu" }
        #expect(gpu?.members == ["gpu.icon", "gpu.label"])
        #expect(gpu?.brackets == ["gpu.bracket"])
    }

    @Test("a widget that is no longer on the bar drops out")
    func dropsMissingWidgets() {
        var saved = BarConfiguration()
        saved.components = [stored()]
        let merged = MenuBarComponents.merge(saved, discovered: [], geometry: [:])
        #expect(merged.components.isEmpty)
    }

    /// A component someone added is theirs; it stays even when SketchyBar has
    /// not been told about it yet.
    @Test("a custom component survives not being discovered")
    func keepsCustom() {
        var component = stored()
        component.kind = "text"
        var saved = BarConfiguration()
        saved.components = [component]
        let merged = MenuBarComponents.merge(saved, discovered: [], geometry: [:])
        #expect(merged.components.count == 1)
        #expect(merged.components.first?.format == "{value}%")
    }
}
