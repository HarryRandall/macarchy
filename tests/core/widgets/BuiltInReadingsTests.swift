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
        #expect(ReadingFormat.hours(185) == "3h 05m" && ReadingFormat.hours(12) == "12m")
        #expect(ReadingFormat.gigabytes(3 * 1_073_741_824 / 2) == "1.50")
        #expect(ReadingFormat.warning(80, warn: 75, alarm: 95) == "#fbbf24")
        #expect(ReadingFormat.warning(96, warn: 75, alarm: 95) == "#f87171")
        #expect(ReadingFormat.warning(10, warn: 75, alarm: 95) == nil)
    }

    @Test("a temperature read where most sensors report nonsense is not learnt from")
    func sensors() {
        #expect(!SMCSensors.believable(5.2) && !SMCSensors.believable(-4))
        #expect(SMCSensors.believable(64.3))
        // The performance cores' sensors all out: 16 of 64 still read.
        #expect(!SMCSensors.trusted(good: 16, working: 64, of: 64))
        #expect(SMCSensors.trusted(good: 61, working: 61, of: 64))
        // The first read has nothing to go on but half of them all.
        #expect(SMCSensors.trusted(good: 40, working: 0, of: 64))
        #expect(!SMCSensors.trusted(good: 16, working: 0, of: 64))
        #expect(!SMCSensors.trusted(good: 0, working: 0, of: 0))
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
        _ = GPUReading.read()
        _ = WiFiReading.read()
        let manifest = WidgetManifest(id: "cpu", name: "CPU")
        let instance = WidgetInstance(
            id: "c", manifest: manifest, directory: URL(fileURLWithPath: "/"), settings: [:],
            visible: true)
        let output = await BuiltInReadings.shared.cpu(instance, now: Date())
        #expect(output.values["load"]?.hasSuffix("%") == true)
    }

    @Test(
        "the battery's dropdown follows the charger: temperature and time left, or rate and time to full"
    )
    func batteryStates() {
        var battery = BatteryReading(
            percent: 33, onAdapter: false, charging: false, charged: false, minutesLeft: 185,
            cycles: 212, health: 94, lowPowerMode: false, temperature: 28.5, watts: -8.9)
        let sample = ReadingOutputs.BatterySample(
            levels: [35, 34, 33], temperatures: [28.4, 28.5], energyMode: "Automatic",
            energyApps: "Claude")
        let unplugged = ReadingOutputs.battery(battery, sample, settings: [:]).values
        #expect(unplugged["headline"] == "33%" && unplugged["remaining.short"] == "3h 05m")
        #expect(unplugged["temperature"] == "28.5°" && unplugged["rate"] == "0 W")
        #expect(unplugged["notCharging"] == "yes" && unplugged["charging"]?.isEmpty == true)
        #expect(unplugged["levels"] == "35.0,34.0,33.0" && unplugged["energyApps"] == "Claude")
        battery.onAdapter = true
        battery.charging = true
        battery.minutesLeft = 80
        battery.watts = 41.6
        let charging = ReadingOutputs.battery(battery, sample, settings: [:]).values
        #expect(charging["headline"] == "33% · Charging" && charging["rate"] == "42 W")
        #expect(charging["charging"] == "yes" && charging["remaining.short"] == "1h 20m")
        battery.charging = false
        battery.charged = true
        #expect(
            ReadingOutputs.battery(battery, sample, settings: [:]).values["remaining.short"]
                == "On power")
    }

    @Test("Energy Mode reads powermode, or Low Power Mode on Macs without it")
    func energyMode() {
        #expect(
            EnergyMode.parse(" sleep 1\n powermode            2\n", lowPowerMode: false)
                == "High Power")
        #expect(EnergyMode.parse(" powermode 1", lowPowerMode: false) == "Low Power")
        #expect(EnergyMode.parse(" powermode 0", lowPowerMode: false) == "Automatic")
        #expect(EnergyMode.parse("", lowPowerMode: true) == "Low Power")
    }

    @Test("each app's share of the GPU is its GPU time over the time between readings")
    func gpuApps() {
        #expect(GPUReading.pid("pid 396, WindowServer") == 396 && GPUReading.pid("kernel") == nil)
        let names: [Int32: String] = [1: "WindowServer", 2: "Claude Helper (GPU)", 3: "Claude"]
        let apps = GPUReading.apps(
            from: [1: 0, 2: 1_000_000_000, 3: 0, 4: 0],
            to: [1: 200_000_000, 2: 1_300_000_000, 3: 100_000_000, 4: 50, 5: 9_000_000_000],
            seconds: 2, name: { names[$0] })
        #expect(apps.map(\.name) == ["Claude", "WindowServer"])
        #expect(apps.map { ($0.share * 10).rounded() / 10 } == [20, 10])
    }

    @Test("network shows Wi-Fi's link only when Wi-Fi is the connection in use")
    func networkLink() {
        let counters = NetworkCounters(
            received: 1_000, sent: 10, interface: "en0", address: "192.168.0.24")
        let wifi = WiFiReading(interface: "en0", rssi: -68, rate: 260, channel: 157, band: "5 GHz")
        let values = ReadingOutputs.network(
            counters,
            .init(
                down: 2048, up: 1024, history: [2], upHistory: [1], wifi: wifi,
                router: "192.168.0.1")
        ).values
        #expect(
            values["kind"] == "Wi-Fi" && values["signal"] == "2" && values["channel"] == "Ch 157")
        #expect(values["link"] == "en0 · 192.168.0.24" && values["rate"] == "260 Mb/s")
        #expect(values["upHistory"] == "1.0" && values["router"] == "192.168.0.1")
        var cable = counters
        cable.interface = "en7"
        let wired = ReadingOutputs.network(cable, .init(down: 0, up: 0, history: [], wifi: wifi))
            .values
        #expect(
            wired["kind"] == "Ethernet" && wired["signal"]?.isEmpty == true
                && wired["band"]?.isEmpty == true)
        let none = ReadingOutputs.network(
            NetworkCounters(received: 0, sent: 0), .init(down: 0, up: 0, history: [])
        ).values
        #expect(none["status"] == "Not connected" && none["icon"] == "wifi.slash")
    }

    @Test("memory gives its parts as numbers for the map, and swap over the minute")
    func memoryMap() {
        let gigabyte: UInt64 = 1_073_741_824
        let reading = MemoryReading(
            total: 24 * gigabyte, app: 12 * gigabyte, wired: 3 * gigabyte, compressed: gigabyte,
            cached: 5 * gigabyte, swapUsed: gigabyte / 4, pressureLevel: 1)
        let values = ReadingOutputs.memory(
            reading, history: [60], swapHistory: [0.25], top: TopProcesses(entries: [])
        ).values
        #expect(values["summary"] == "16.0 of 24 GB" && values["percent.short"] == "67%")
        #expect(values["app.gb"] == "12.00" && values["total.gb"] == "24.00")
        #expect(values["swap.short"] == "0.2G" || values["swap.short"] == "0.3G")
        #expect(values["swapHistory"] == "0.25")
    }

    @Test("significant energy counts apps only, with their helpers, busiest first")
    func energyApps() {
        let text = """
              40.0 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
               8.0 /Applications/Firefox.app/Contents/MacOS/firefox
               6.0 /Applications/Firefox.app/Contents/MacOS/plugin-container
              30.0 /Applications/Claude.app/Contents/Frameworks/Claude Helper (GPU).app/Contents/MacOS/Claude Helper (GPU)
               3.0 /System/Applications/Mail.app/Contents/MacOS/Mail
            """
        #expect(EnergyApps.parse(text) == "Claude,Firefox")
    }
}
