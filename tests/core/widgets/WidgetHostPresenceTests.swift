import Darwin
import Foundation
import Testing

@testable import Macarchy

@Suite("Widget host presence and the clock's fallback")
struct WidgetHostPresenceTests {
    @Test("a host holds the lock while it runs, and only then is it seen")
    func presence() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "presence-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "state/widget-host.lock")
        #expect(WidgetHostPresence.hold(at: url) == nil, "Before setup the folder is not made")
        #expect(!FileManager.default.fileExists(atPath: root.path))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(!WidgetHostPresence.isHeld(at: url))
        let descriptor = try #require(WidgetHostPresence.hold(at: url))
        #expect(WidgetHostPresence.isHeld(at: url))
        #expect(WidgetHostPresence.hold(at: url) == nil, "A second host does not take it")
        close(descriptor)
        #expect(!WidgetHostPresence.isHeld(at: url))
    }

    @Test("a clock asks SketchyBar to run its fallback; other widgets do not")
    func clockFallback() throws {
        let catalogue = WidgetCatalogue(
            builtIn: WidgetManifestTests.builtIn,
            user: FileManager.default.temporaryDirectory.appending(path: "none-\(UUID())"))
        let look = WidgetLook.current(catalogue: catalogue, theme: nil)
        let bar = look.normalised(.widgetDefault)
        let clock = try #require(bar.components.first { $0.widget == "clock" })
        let arguments = look.arguments(for: clock)
        #expect(arguments.last == "update_freq=\(WidgetLook.fallbackSeconds)")
        #expect(arguments.contains("script=\(look.command) widget fallback 'macarchy.clock'"))
        let battery = try #require(bar.components.first { $0.widget == "battery" })
        #expect(look.arguments(for: battery).last == "update_freq=0")
    }
}
