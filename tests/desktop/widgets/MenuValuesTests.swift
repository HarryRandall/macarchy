import Testing

@testable import App

@Suite("Dropdown row values")
struct MenuValuesTests {
    @Test("a graph reads numbers, ignoring units and stray separators")
    func numbers() {
        #expect(MenuValues.numbers("12, 30,45%,61.5°") == [12, 30, 45, 61.5])
        #expect(MenuValues.numbers("none").isEmpty)
    }

    @Test("cores read as groups split by a bar")
    func groups() {
        #expect(MenuValues.groups("62,48|80,74") == [[62, 48], [80, 74]])
        #expect(MenuValues.groups("|5") == [[5]])
    }

    @Test("apps read as names with optional values")
    func apps() {
        let apps = MenuValues.apps("Firefox:9%, Claude ,Activity Monitor:1.2%")
        #expect(apps.map(\.name) == ["Firefox", "Claude", "Activity Monitor"])
        #expect(apps.map(\.value) == ["9%", "", "1.2%"])
    }
}
