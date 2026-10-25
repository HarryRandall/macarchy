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

    private func items(_ widget: String, _ output: WidgetOutput) throws -> [WidgetMenuItem] {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../resources/widgets/\(widget)")
        let manifest = try JSONDecoder().decode(
            WidgetManifest.self, from: Data(contentsOf: folder.appending(path: "widget.json")))
        let instance = WidgetInstance(
            id: "macarchy.\(widget)", manifest: manifest, directory: folder, settings: [:],
            visible: true)
        return WidgetMenu.items(instance: instance, component: nil, output: output, label: "")
    }

    private func wave(_ base: Double, _ swing: Double, spikes: Bool = false) -> [Double] {
        (0..<30).map {
            base + swing * sin(Double($0) / 2.5) + (spikes && $0 % 7 == 3 ? base * 6 : 0)
        }
    }

    /// Opens a dropdown off screen, then points at each spot given.
    private func open(
        _ items: [WidgetMenuItem], as name: String, pointing: [CGPoint] = []
    )
        throws -> NSView
    {
        let model = WidgetMenuModel()
        model.items = items
        let view = host(model)
        _ = try draw(view, as: name)
        for (index, spot) in pointing.enumerated() {
            model.pointer = spot
            _ = try draw(view, as: "\(name)-hover-\(index + 1)")
        }
        return view
    }

    @Test("Network draws its Wi-Fi card and download over upload")
    func network() throws {
        let output = ReadingOutputs.network(
            NetworkCounters(
                received: 1_331_000_000, sent: 341_000_000, interface: "en0",
                address: "192.168.0.24"),
            .init(
                down: 38 * 1024, up: 77 * 1024, history: wave(40, 20, spikes: true),
                upHistory: wave(20, 12, spikes: true),
                wifi: WiFiReading(
                    interface: "en0", rssi: -58, rate: 866, channel: 149, band: "5 GHz"),
                router: "192.168.0.1"))
        let items = try items("network", output)
        #expect(items.map(\.type).prefix(3) == ["heading", "status", "mirror"])
        let view = try open(items, as: "network-dropdown", pointing: [CGPoint(x: 150, y: 140)])
        #expect(view.bounds.width == WidgetMenuView.width)
    }

    @Test("Memory draws used and swap cards over its map")
    func memory() throws {
        let gigabyte: UInt64 = 1_073_741_824
        let reading = MemoryReading(
            total: 24 * gigabyte, app: 11 * gigabyte, wired: 36 * gigabyte / 10,
            compressed: 17 * gigabyte / 10, cached: 49 * gigabyte / 10, swapUsed: gigabyte / 4,
            pressureLevel: 1)
        let output = ReadingOutputs.memory(
            reading, history: wave(68, 2), swapHistory: wave(0.25, 0.05),
            top: TopProcesses.parse("1 3400000 Claude\n1 2100000 Safari\n1 1200000 WindowServer"))
        let items = try items("memory", output)
        #expect(
            WidgetMenuView.blocks(items).first { $0.count == 2 }?.map(\.label) == ["Used", "Swap"])
        _ = try open(items, as: "memory-dropdown", pointing: [CGPoint(x: 40, y: 130)])
    }

    @Test("GPU draws load and temperature over the memory it holds")
    func gpu() throws {
        let output = ReadingOutputs.gpu(
            .init(
                load: 42, temperature: 44.2, history: wave(40, 20), temperatures: wave(44, 2),
                memory: 2_250_000_000, memoryLimit: 19_069_665_280, cores: 20,
                top: "WindowServer:12.4%,Claude:5.1%,Safari:2.0%"),
            settings: [:])
        let items = try items("gpu", output)
        #expect(items.first?.value == "20-core")
        _ = try open(items, as: "gpu-dropdown")
    }

    @Test("Battery shows temperature and time left unplugged, and rate and time to full charging")
    func battery() throws {
        var reading = BatteryReading(
            percent: 33, onAdapter: false, charging: false, charged: false, minutesLeft: 185,
            cycles: 212, health: 94, lowPowerMode: false, temperature: 31.4, watts: -12)
        let sample = ReadingOutputs.BatterySample(
            levels: (0..<30).map { 48 - Double($0) / 2 }, temperatures: wave(31, 0.6),
            rates: wave(42, 4), energyMode: "Automatic", energyApps: "Claude")
        let unplugged = try items(
            "battery", ReadingOutputs.battery(reading, sample, settings: [:]))
        #expect(
            WidgetMenuView.blocks(unplugged).first { $0.count == 2 }?.map(\.label) == [
                "Temp", "Left"
            ])
        _ = try open(unplugged, as: "battery-dropdown")
        reading.onAdapter = true
        reading.charging = true
        reading.minutesLeft = 80
        reading.watts = 41.6
        let charging = try items("battery", ReadingOutputs.battery(reading, sample, settings: [:]))
        #expect(
            WidgetMenuView.blocks(charging).first { $0.count == 2 }?.map(\.label) == [
                "Rate", "Full"
            ])
        _ = try open(charging, as: "battery-dropdown-charging")
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
