import Testing

@testable import App

struct WidgetBoxTests {
    @Test("highlighting a borderless item never reveals its dormant outline")
    func borderless() {
        let normal = WidgetBox.Background(
            drawing: "off", colour: "0x0", borderWidth: 1, borderColour: "0x33ffffff")
        #expect(normal.highlighted.drawing == "on")
        #expect(normal.highlighted.borderWidth == 0)
        #expect(normal.drawing == "off" && normal.borderWidth == 1)
    }

    @Test("an outlined widget keeps its own border while highlighted")
    func outlined() {
        let normal = WidgetBox.Background(
            drawing: "on", colour: "0x0", borderWidth: 2, borderColour: "0xff123456")
        #expect(normal.highlighted.borderWidth == 2)
        #expect(normal.highlighted.borderColour == "0xff123456")
    }
}
