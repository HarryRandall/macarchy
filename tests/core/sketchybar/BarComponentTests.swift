import Foundation
import Testing

@testable import Macarchy

/// The appearance fields were added after menu bars were already being saved,
/// so the decoding case matters as much as the rendering one: a bar written
/// before they existed still has to load.
@Suite("BarComponent")
struct BarComponentTests {
    private func sample() -> BarComponent {
        BarComponent(id: "cpu", title: "CPU", side: "right", members: ["cpu"])
    }

    @Test("a reading is written out through the format")
    func rendersFormat() {
        var component = sample()
        component.format = "{value}%"
        #expect(component.rendered("47") == "47%")
        #expect(component.rendered("0.00") == "0.00%")
    }

    @Test("every occurrence of the placeholder is filled in")
    func rendersRepeatedPlaceholder() {
        var component = sample()
        component.format = "{value} / {value}"
        #expect(component.rendered("3") == "3 / 3")
    }

    @Test("no format leaves the reading untouched")
    func rendersWithoutFormat() {
        var component = sample()
        #expect(component.rendered("47") == "47")
        component.format = ""
        #expect(component.rendered("47") == "47")
    }

    /// The studio needs something to draw even before samples are configured.
    @Test("samples fall back to a spread from empty to full")
    func defaultSamples() {
        #expect(sample().samples == ["0", "47", "100"])
    }

    @Test("configured samples are used as given")
    func configuredSamples() {
        var component = sample()
        component.sampleValues = ["Paused", "Blue Monday"]
        #expect(component.samples == ["Paused", "Blue Monday"])
    }

    /// A menu bar saved before the appearance fields existed must still load.
    @Test("a component saved without the appearance fields still decodes")
    func decodesWithoutAppearanceFields() throws {
        let json = """
            {"id":"cpu","title":"CPU","side":"right","members":["cpu"],
             "brackets":[],"visible":true,"drawing":{},"spacing":0,
             "text":"","icon":"","customWidth":24}
            """
        let component = try JSONDecoder().decode(
            BarComponent.self, from: Data(json.utf8))
        #expect(component.id == "cpu")
        #expect(component.format == nil)
        #expect(component.cornerRadius == 0)
        #expect(component.sampleValues.isEmpty)
        #expect(component.iconColour == nil)
    }

    @Test("appearance fields survive a round trip")
    func roundTripsAppearance() throws {
        var component = sample()
        component.format = "{value}%"
        component.iconColour = "0xffff0000"
        component.backgroundColour = "0xff112233"
        component.cornerRadius = 6
        component.sampleValues = ["0", "100"]

        let data = try JSONEncoder().encode(component)
        let decoded = try JSONDecoder().decode(BarComponent.self, from: data)
        #expect(decoded == component)
        #expect(decoded.rendered("12") == "12%")
    }
}
