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
        "battery": { instance, _ in await shared.battery(instance) }
    ]

    /// Points kept for each graph: a minute at the usual two seconds.
    static let historyLength = 30

    private var ticks: [CoreTicks] = []
    private var counters: (reading: NetworkCounters, at: Date)?
    private var histories: [String: [Double]] = [:]
    private var processes: (list: TopProcesses, at: Date)?

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

    func cpu(_ instance: WidgetInstance, now: Date) async -> WidgetOutput {
        let current = CoreTicks.read()
        let loads = CoreTicks.loads(from: ticks.isEmpty ? current : ticks, to: current)
        ticks = current
        let load = loads.isEmpty ? 0 : loads.reduce(0, +) / Double(loads.count)
        let sample = ReadingOutputs.CPUSample(
            load: load, cores: loads, temperature: SMCSensors.shared.read().cpu,
            history: remember(load, as: "cpu"))
        return ReadingOutputs.cpu(
            sample, processor: .current,
            top: await topProcesses(now: now), settings: instance.settings)
    }

    func gpu(_ instance: WidgetInstance, now: Date) -> WidgetOutput {
        let load = GPUUsage.read() ?? 0
        return ReadingOutputs.gpu(
            load: load, temperature: SMCSensors.shared.read().gpu,
            history: remember(load, as: "gpu"), settings: instance.settings)
    }

    func memory(_ instance: WidgetInstance, now: Date) async -> WidgetOutput? {
        guard let reading = MemoryReading.read() else { return nil }
        return ReadingOutputs.memory(
            reading, history: remember(reading.percent, as: "memory"),
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
            reading, down: down, up: up, history: remember(down / 1024, as: "network"))
    }

    func battery(_ instance: WidgetInstance) -> WidgetOutput? {
        BatteryReading.read().map { ReadingOutputs.battery($0, settings: instance.settings) }
    }
}
