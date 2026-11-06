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

    @Test("points are written in their unit, with rates in kilobytes growing to megabytes")
    func format() {
        #expect(MenuValues.format(12.4, unit: "%") == "12%")
        #expect(MenuValues.format(47.25, unit: "°").hasPrefix("47."))
        #expect(MenuValues.format(512, unit: "KB/s") == "512KB/s")
        #expect(MenuValues.format(1536, unit: "KB/s") == "1.5MB/s")
        #expect(MenuValues.format(41.6, unit: "W") == "42 W")
        #expect(
            MenuValues.format(0.25, unit: "G") == "0.2G"
                || MenuValues.format(0.25, unit: "G") == "0.3G")
        #expect(MenuValues.format(3.6, unit: "GB") == "3.6 GB")
    }

    @Test("a map gives each part its rounded share of the blocks, and leaves the rest empty")
    func map() {
        let owners = MenuMap.owners([11, 3.6, 1.7, 4.9], total: 24, cells: 96)
        #expect(owners.count == 96)
        #expect(owners.filter { $0 == 0 }.count == 44 && owners.filter { $0 == 1 }.count == 14)
        #expect(owners.filter { $0 == nil }.count == 96 - 44 - 14 - 7 - 20)
        #expect(MenuMap.owners([30], total: 24, cells: 16) == Array(repeating: 0, count: 16))
        #expect(MenuMap.owners([1, 1], total: 0, cells: 16).filter { $0 == nil }.isEmpty)
        #expect(MenuMap.owners([], total: 0, cells: 16) == Array(repeating: nil, count: 16))
    }
}
