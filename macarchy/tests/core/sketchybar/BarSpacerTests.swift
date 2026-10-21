import Testing

@testable import Macarchy

@Suite("Spacer components")
struct BarSpacerTests {
    @Test("a spacer reserves exactly its authored width despite global spacing")
    func exactWidth() throws {
        var spacer = BarComponent(id: "space", title: "Spacer", side: "center", members: ["space"])
        spacer.kind = "spacer"
        spacer.boxWidth = 7
        var configuration = BarConfiguration()
        configuration.components = [spacer]
        configuration.componentPadding = 12
        configuration.componentSpacing = 18
        try configuration.validate()
        #expect(configuration.padding(for: spacer) == 0)
        #expect(configuration.spacing(for: spacer) == 0)
        let settings = BarCommands.settings(configuration)
        #expect(settings.contains("width=7.0"))
        #expect(settings.contains("icon.drawing=off"))
        #expect(settings.contains("label.drawing=off"))
        #expect(!settings.contains("padding_left=12.0"))
        #expect(!settings.contains("padding_right=18.0"))
        #expect(settings.contains("background.drawing=off"))
    }
}
