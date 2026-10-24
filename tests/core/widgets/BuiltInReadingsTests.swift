import Foundation
import Testing

@testable import Macarchy

@Suite("Built-in readings")
struct BuiltInReadingsTests {
    @Test("readings keep a fixed shape on the bar")
    func formats() {
        #expect(ReadingFormat.percent(12.345) == "12.3%")
        #expect(ReadingFormat.percent(140) == "100.0%")
        #expect(ReadingFormat.degrees(47.25) == "47.3°" || ReadingFormat.degrees(47.25) == "47.2°")
        #expect(ReadingFormat.degrees(nil) == "--")
        #expect(ReadingFormat.bytes(5 * 1_073_741_824) == "5.0G")
        #expect(ReadingFormat.bytes(512 * 1_048_576) == "512M")
        #expect(ReadingFormat.bytesLong(5 * 1_073_741_824) == "5.0 GB")
        #expect(ReadingFormat.rate(1_572_864) == "1.5MB/s")
        #expect(ReadingFormat.rate(512 * 1024) == "512KB/s")
        #expect(ReadingFormat.duration(192) == "3:12")
        #expect(ReadingFormat.warning(80, warn: 75, alarm: 95) == "#fbbf24")
        #expect(ReadingFormat.warning(96, warn: 75, alarm: 95) == "#f87171")
        #expect(ReadingFormat.warning(10, warn: 75, alarm: 95) == nil)
    }

    @Test("load is the busy share of ticks between two readings")
    func loads() {
        let earlier = [CoreTicks(busy: 100, total: 200), CoreTicks(busy: 0, total: 100)]
        let later = [CoreTicks(busy: 150, total: 300), CoreTicks(busy: 100, total: 200)]
        #expect(CoreTicks.loads(from: earlier, to: later) == [50, 100])
        #expect(CoreTicks.loads(from: [], to: later) == [0, 0])
    }

    @Test("helpers count towards their app, busiest first")
    func processes() {
        let top = TopProcesses.parse(
            """
              30.0  1024 Firefox
              20.0  2048 Firefox GPU Helper
              25.0   512 Claude Helper (Renderer)
               1.0 99999 WindowServer
            """)
        #expect(top.byCPU(2) == "Firefox:50.0%,Claude:25.0%")
        #expect(top.byMemory(1).hasPrefix("WindowServer:"))
        #expect(TopProcesses.appName("Code Helper (Plugin)") == "Code")
    }

    @Test("the clock's settings build its format, and the dropdown's zones are read")
    func clock() {
        #expect(ClockReading.pattern([:]) == "EEE d MMM hh:mm a")
        #expect(
            ClockReading.pattern([
                "order": .text("month-day"), "twentyFourHour": .bool(true), "year": .bool(true),
                "leadingZero": .bool(false), "seconds": .bool(true)
            ]) == "EEE MMM d yyyy H:mm:ss")
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        manifest.click = WidgetClick(dropdown: [
            WidgetMenuRow(type: "reading", label: "London", value: "{time:Europe/London}")
        ])
        let instance = WidgetInstance(
            id: "macarchy.clock", manifest: manifest, directory: URL(fileURLWithPath: "/"),
            settings: ["twentyFourHour": .bool(true)], visible: true)
        #expect(ClockReading.zonesAsked(instance) == ["Europe/London"])
        let output = ClockReading.output(instance, now: Date(timeIntervalSince1970: 0))
        #expect(output.values["time:Europe/London"] == "01:00")
    }

    @Test("a clock showing seconds updates every second")
    func seconds() {
        var manifest = WidgetManifest(id: "clock", name: "Clock")
        manifest.update = WidgetUpdate(every: "minute")
        func instance(_ seconds: Bool) -> WidgetInstance {
            WidgetInstance(
                id: "c", manifest: manifest, directory: URL(fileURLWithPath: "/"),
                settings: ["seconds": .bool(seconds)], visible: true)
        }
        #expect(instance(true).every == "second" && instance(false).every == "minute")
    }

    @Test("CPU lines warn past their settings; the battery colours its glyph")
    func outputs() {
        let cpu = ReadingOutputs.cpu(
            .init(load: 80, cores: [10, 20, 90, 95], temperature: 50, history: [1, 2]),
            processor: ProcessorInfo(chip: "M4", performance: 2, efficiency: 2),
            top: TopProcesses(entries: []), settings: [:])
        #expect(cpu.label == "80.0%\n50.0°")
        #expect(cpu.lineColours == ["#fbbf24", nil])
        #expect(cpu.values["cores"] == "90,95|10,20")
        var battery = BatteryReading(
            percent: 8, onAdapter: false, charging: false, charged: false, minutesLeft: 30,
            cycles: 120, health: 91, lowPowerMode: false)
        #expect(ReadingOutputs.battery(battery, settings: [:]).iconColour == "#f87171")
        battery.onAdapter = true
        battery.charging = true
        battery.percent = 50
        let charging = ReadingOutputs.battery(battery, settings: [:])
        #expect(
            charging.iconColour == "#4ade80" && charging.values["remainingLabel"] == "Until full")
        #expect(
            ReadingOutputs.battery(battery, settings: ["showPercent": .bool(false)]).label?.isEmpty
                == true)
    }

    @Test("this Mac gives real readings without anything installed")
    func live() async {
        #expect(!CoreTicks.read().isEmpty)
        #expect(MemoryReading.read().map { $0.total > 0 && $0.used > 0 } == true)
        _ = NetworkCounters.read()
        _ = SMCSensors.shared.read()
        _ = GPUUsage.read()
        let manifest = WidgetManifest(id: "cpu", name: "CPU")
        let instance = WidgetInstance(
            id: "c", manifest: manifest, directory: URL(fileURLWithPath: "/"), settings: [:],
            visible: true)
        let output = await BuiltInReadings.shared.cpu(instance, now: Date())
        #expect(output.values["load"]?.hasSuffix("%") == true)
    }
}
