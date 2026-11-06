import Foundation
import Testing

@testable import Macarchy

/// What setup writes into settings that have never been set up, and leaves
/// alone in settings that have.
@Suite("Fresh install defaults")
struct FreshInstallTests {
    @Test("new settings start with the theme, floating apps and square borders")
    func seeds() {
        var document = SettingsDocument()
        Setup.seedDefaults(&document)
        #expect(document.currentTheme == "awakening")
        #expect(document.floatingApps == ["FaceTime", "iPhone Mirroring"])
        let values = document.flatValues
        #expect(values["BORDER_RADIUS"] == "0.3" && values["BORDERS_VISIBLE"] == "true")
        let arguments = BorderCommand.arguments(values: values, theme: nil)
        #expect(arguments.contains("width=7") && arguments.contains("style=square"))
        #expect(arguments.contains("blacklist=iPhone Mirroring"))
    }

    @Test("settings that were set up before keep what they have")
    func keeps() {
        var document = SettingsDocument()
        document.currentTheme = "lumon"
        Setup.seedDefaults(&document)
        #expect(document.floatingApps.isEmpty && document.borders.isEmpty)

        var partial = SettingsDocument()
        partial.floatingApps = ["Calculator"]
        partial.mergeFlat(["BORDER_WIDTH": "3"])
        Setup.seedDefaults(&partial)
        #expect(partial.currentTheme == "awakening")
        #expect(partial.floatingApps == ["Calculator"])
        #expect(partial.flatValues["BORDER_WIDTH"] == "3" && partial.borders.count == 1)
    }

    @Test("the bar's right-hand widgets have no box and the clock is 24-hour with no icon")
    func bar() throws {
        let bar = BarConfiguration.widgetDefault
        try bar.validate()
        #expect(bar.widgetGap == 2 && bar.widgetInset == 4 && bar.widgetHeight == 24)
        let right = bar.components.filter { $0.side == "right" }
        #expect(right.map(\.widget) == ["network", "memory", "gpu", "cpu", "battery", "clock"])
        #expect(right.allSatisfy { $0.style?.box == "none" })
        #expect(bar.components[0].widget == "spaces" && bar.components[0].style == nil)
        let clock = try #require(right.last)
        #expect(clock.settings == ["twentyFourHour": .bool(true)])
        #expect(clock.style?.showIcon == false && clock.style?.iconColour == "text")
    }
}
