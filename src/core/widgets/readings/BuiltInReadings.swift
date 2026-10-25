import Foundation

/// The readings built-in widgets name as their `source`, taken by Macarchy
/// itself from the system, with nothing extra installed.
///
/// Load and network speed are changes between two readings, so the previous
/// counters are kept, along with a short history for each dropdown's graph.
public actor BuiltInReadings {
    public static let shared = BuiltInReadings()

    /// The sources by name, for `WidgetHost`.
    public static let sources: [String: WidgetHost.Source] = [
        "date": { instance, now in ClockReading.output(instance, now: now) },
        "cpu": { instance, now in await shared.cpu(instance, now: now) },
        "gpu": { instance, now in await shared.gpu(instance, now: now) },
        "memory": { instance, now in await shared.memory(instance, now: now) },
        "network": { instance, now in await shared.network(instance, now: now) },
        "battery": { instance, now in await shared.battery(instance, now: now) },
        "spaces": { instance, _ in await shared.spaces(instance) }
    ]

    /// Points kept for each graph: a minute at the usual two seconds.
    static let historyLength = 30

    private var ticks: [CoreTicks] = []
    private var counters: (reading: NetworkCounters, at: Date)?
    private var histories: [String: [Double]] = [:]
    private var processes: (list: TopProcesses, at: Date)?
    /// Each process's GPU time when last read, for the share since.
    private var gpuTime: (time: [Int32: UInt64], at: Date)?
    /// Each Spaces widget folder's icon map, read once.
    private var icons: [URL: AppIcons] = [:]
    /// The Spaces and windows last read, for showing a switch straight away.
    private var lastSpaces: SpacesReading?
    /// The Space `macarchy space` is going to, when it asked, and whether
    /// it has been drawn yet.
    private struct Expected {
        var index: Int
        var at: Date
        var shown = false
    }
    private var expected: Expected?

    /// The Space about to be shown, which the next update draws as current
    /// from what was last read, without waiting on yabai or macOS.
    public func expect(space index: Int) {
        expected = Expected(index: index, at: Date())
    }

    private var temperatures: [String: Double] = [:]

    /// A temperature eased towards each new reading, so a sensor's
    /// momentary spike from a burst of work moves it only part of the way.
    private func smoothed(_ reading: Double?, as name: String) -> Double? {
        guard let reading else { return temperatures[name] }
        let eased = temperatures[name].map { $0 + (reading - $0) * 0.5 } ?? reading
        temperatures[name] = eased
        return eased
    }

    private func remember(_ value: Double, as name: String) -> [Double] {
        let history = Array(((histories[name] ?? []) + [value]).suffix(Self.historyLength))
        histories[name] = history
        return history
    }

    /// The process list, read at most every few seconds however many
    /// widgets ask for it.
    private func topProcesses(now: Date) async -> TopProcesses {
        if let processes, now.timeIntervalSince(processes.at) < 4 { return processes.list }
        let list = await TopProcesses.read()
        processes = (list, now)
        return list
    }

    func spaces(_ instance: WidgetInstance) async -> WidgetOutput? {
        guard let reading = await spacesReading() else { return nil }
        let map = icons[instance.directory] ?? AppIcons.load(from: instance.directory)
        icons[instance.directory] = map
        return ReadingOutputs.spaces(
            reading, icons: map, slots: instance.style.row ?? 10, settings: instance.settings)
    }

    /// The first update after `expect` draws from the last reading; later
    /// ones read afresh, keeping the expected Space current until macOS
    /// says it is, or a moment has passed and it evidently did not switch.
    private func spacesReading() async -> SpacesReading? {
        if let target = expected, Date().timeIntervalSince(target.at) > 1.5 { expected = nil }
        if let target = expected, !target.shown, let last = lastSpaces {
            expected?.shown = true
            return last.showing(target.index)
        }
        guard let reading = await SpacesReading.read() else { return nil }
        lastSpaces = reading
        guard let target = expected else { return reading }
        if reading.spaces.contains(where: { $0.index == target.index && $0.visible }) {
            expected = nil
            return reading
        }
        return reading.showing(target.index)
    }

    func cpu(_ instance: WidgetInstance, now: Date) async -> WidgetOutput {
        let current = CoreTicks.read()
        let loads = CoreTicks.loads(from: ticks.isEmpty ? current : ticks, to: current)
        ticks = current
        let load = loads.isEmpty ? 0 : loads.reduce(0, +) / Double(loads.count)
        let temperature = smoothed(SMCSensors.shared.read().cpu, as: "cpu")
        var sample = ReadingOutputs.CPUSample(
            load: load, cores: loads, temperature: temperature,
            history: remember(load, as: "cpu"))
        if let temperature { sample.temperatures = remember(temperature, as: "cpu.temperature") }
        return ReadingOutputs.cpu(
            sample, processor: .current,
            top: await topProcesses(now: now), settings: instance.settings)
    }

    func gpu(_ instance: WidgetInstance, now: Date) -> WidgetOutput {
        let reading = GPUReading.read()
        let load = reading?.load ?? 0
        var top = ""
        if let reading, let earlier = gpuTime {
            top = GPUReading.apps(
                from: earlier.time, to: reading.time, seconds: now.timeIntervalSince(earlier.at)
            )
            .prefix(3).map { "\($0.name):\(String(format: "%.1f%%", $0.share))" }
            .joined(separator: ",")
        }
        if let reading { gpuTime = (reading.time, now) }
        let temperature = smoothed(SMCSensors.shared.read().gpu, as: "gpu")
        var sample = ReadingOutputs.GPUSample(
            load: load, temperature: temperature, history: remember(load, as: "gpu"),
            memory: reading?.memory, memoryLimit: GPUReading.memoryLimit, cores: reading?.cores,
            top: top)
        if let temperature { sample.temperatures = remember(temperature, as: "gpu.temperature") }
        return ReadingOutputs.gpu(sample, settings: instance.settings)
    }

    func memory(_ instance: WidgetInstance, now: Date) async -> WidgetOutput? {
        guard let reading = MemoryReading.read() else { return nil }
        return ReadingOutputs.memory(
            reading, history: remember(reading.percent, as: "memory"),
            swapHistory: remember(Double(reading.swapUsed) / 1_073_741_824, as: "memory.swap"),
            top: await topProcesses(now: now))
    }

    func network(_ instance: WidgetInstance, now: Date) -> WidgetOutput {
        let reading = NetworkCounters.read()
        var down = 0.0
        var up = 0.0
        if let counters, now > counters.at, reading.received >= counters.reading.received,
            reading.sent >= counters.reading.sent
        {
            let seconds = now.timeIntervalSince(counters.at)
            down = Double(reading.received - counters.reading.received) / seconds
            up = Double(reading.sent - counters.reading.sent) / seconds
        }
        counters = (reading, now)
        return ReadingOutputs.network(
            reading,
            .init(
                down: down, up: up, history: remember(down / 1024, as: "network"),
                upHistory: remember(up / 1024, as: "network.up"), wifi: WiFiReading.read(),
                router: WiFiReading.router()))
    }

    func battery(_ instance: WidgetInstance, now: Date) async -> WidgetOutput? {
        guard let reading = BatteryReading.read() else { return nil }
        var sample = ReadingOutputs.BatterySample(
            levels: remember(Double(reading.percent), as: "battery"),
            energyMode: await EnergyMode.read(lowPowerMode: reading.lowPowerMode),
            energyApps: await EnergyApps.read())
        if let temperature = reading.temperature {
            sample.temperatures = remember(temperature, as: "battery.temperature")
        }
        // Charging restarts the rate's history, so it shows this charge only.
        if reading.charging, let watts = reading.watts {
            sample.rates = remember(max(watts, 0), as: "battery.rate")
        } else {
            histories["battery.rate"] = nil
        }
        return ReadingOutputs.battery(reading, sample, settings: instance.settings)
    }
}
