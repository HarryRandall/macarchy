import AppKit
import Foundation
import SwiftUI
import Testing

@testable import App
@testable import Macarchy

/// Draws the CPU dropdown off screen, as it would open, and pointed at.
/// Set MACARCHY_SNAPSHOT_DIR to keep the pictures for a look.
@MainActor
@Suite("Widget dropdown drawing")
struct WidgetMenuDrawingTests {
    private func cpuItems() throws -> [WidgetMenuItem] {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../resources/widgets/cpu")
        let manifest = try JSONDecoder().decode(
            WidgetManifest.self, from: Data(contentsOf: folder.appending(path: "widget.json")))
        let instance = WidgetInstance(
            id: "macarchy.cpu", manifest: manifest, directory: folder, settings: [:], visible: true)
        let loads = (0..<30).map { 15 + 10 * sin(Double($0) / 3) + ($0 > 20 ? 25 : 0) }
        let temperatures = (0..<30).map { 60 + 25 * sin(Double($0) / 6) }
        var sample = ReadingOutputs.CPUSample(
            load: 18, cores: [30, 22, 12, 8, 26, 33, 41, 18, 9, 6, 15, 19, 24, 13],
            temperature: temperatures.last, history: loads)
        sample.temperatures = temperatures
        let output = ReadingOutputs.cpu(
            sample, processor: ProcessorInfo(chip: "Apple M4 Pro", performance: 10, efficiency: 4),
            top: TopProcesses.parse("72.8 1 Firefox\n44.8 1 WindowServer\n31.4 1 MacarchySettings"),
            settings: [:])
        return WidgetMenu.items(instance: instance, component: nil, output: output, label: "")
    }

    /// The view in an off-screen window, so it keeps its state between
    /// pointer moves, as the real panel does.
    private func host(_ model: WidgetMenuModel) -> NSHostingView<some View> {
        let host = NSHostingView(rootView: WidgetMenuView(model: model))
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = NSColor(white: 0.16, alpha: 1)
        window.contentView = host
        settle(host)
        return host
    }

    private func settle(_ view: NSView) {
        for _ in 0..<4 {
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func draw(_ host: NSView, as name: String) throws -> NSBitmapImageRep {
        settle(host)
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let folder = ProcessInfo.processInfo.environment["MACARCHY_SNAPSHOT_DIR"],
            let png = bitmap.representation(using: .png, properties: [:])
        {
            try png.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
        }
        return bitmap
    }

    @Test("the CPU dropdown draws its cards, cores and apps, and answers the pointer")
    func cpu() throws {
        let items = try cpuItems()
        #expect(
            WidgetMenuView.blocks(items).first { $0.count == 2 }?.map(\.label) == ["Load", "Temp"])
        let model = WidgetMenuModel()
        model.items = items
        let view = host(model)
        let still = try draw(view, as: "cpu-dropdown")
        #expect(view.bounds.width == WidgetMenuView.width && view.bounds.height > 300)
        // Point at the temperature card's middle, then a core.
        model.pointer = CGPoint(x: 225, y: 75)
        let pointed = try draw(view, as: "cpu-dropdown-temp-hover")
        #expect(
            still.representation(using: .png, properties: [:])
                != pointed.representation(using: .png, properties: [:]))
        model.pointer = CGPoint(x: 80, y: 150)
        _ = try draw(view, as: "cpu-dropdown-core-hover")
    }

    @Test("core rows are even and line up between the groups")
    func columns() {
        #expect(WidgetMenu.coreColumns(4, other: 6) == 4)
        #expect(WidgetMenu.coreColumns(6, other: 4) == 6)
        #expect(WidgetMenu.coreColumns(8, other: 4) == 4)
        #expect(WidgetMenu.coreColumns(10, other: 4) == 5)
        #expect(WidgetMenu.coreColumns(12, other: 4) == 6)
        #expect(WidgetMenu.coreColumns(24, other: 8) == 8)
        #expect(WidgetMenu.coreColumns(8, other: 24) == 8)
    }
}
