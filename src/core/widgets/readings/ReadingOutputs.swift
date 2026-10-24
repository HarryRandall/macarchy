import Foundation

/// What each built-in widget shows for a reading: its label, colours and
/// the values its dropdown rows name. Pure, so tests can feed it readings.
enum ReadingOutputs {
    /// One CPU reading: overall and per-core load, and the die temperature.
    struct CPUSample: Equatable, Sendable {
        var load: Double
        var cores: [Double]
        var temperature: Double?
        var history: [Double]
    }

    static func number(
        _ settings: [String: SettingValue], _ key: String, _ fallback: Double
    )
        -> Double
    {
        if case .number(let value) = settings[key] { return value }
        return fallback
    }

    static func cpu(
        _ sample: CPUSample, processor: ProcessorInfo, top: TopProcesses,
        settings: [String: SettingValue]
    ) -> WidgetOutput {
        let (load, cores, temperature, history) = (
            sample.load, sample.cores, sample.temperature, sample.history
        )
        let efficiency = Array(cores.prefix(processor.efficiency))
        let performance = Array(cores.dropFirst(processor.efficiency))
        func list(_ values: [Double]) -> String {
            values.map { String(format: "%.0f", $0) }.joined(separator: ",")
        }
        var output = WidgetOutput(
            label: ReadingFormat.percent(load) + "\n" + ReadingFormat.degrees(temperature),
            values: [
                "load": ReadingFormat.percent(load),
                "load.short": ReadingFormat.wholePercent(load),
                "temperature": ReadingFormat.degrees(temperature),
                "history": ReadingFormat.history(history),
                "cores": list(performance) + "|" + list(efficiency),
                "cores.performance": String(processor.performance),
                "cores.efficiency": String(processor.efficiency),
                "chip": processor.chip,
                "top": top.byCPU()
            ])
        output.lineColours = [
            ReadingFormat.warning(load, warn: number(settings, "warnLoad", 75), alarm: 95),
            ReadingFormat.warning(
                temperature, warn: number(settings, "warnTemperature", 80), alarm: 95)
        ]
        return output
    }

    static func gpu(
        load: Double, temperature: Double?, history: [Double], settings: [String: SettingValue]
    ) -> WidgetOutput {
        var output = WidgetOutput(
            label: ReadingFormat.percent(load) + "\n" + ReadingFormat.degrees(temperature),
            values: [
                "load": ReadingFormat.percent(load),
                "load.short": ReadingFormat.wholePercent(load),
                "temperature": ReadingFormat.degrees(temperature),
                "history": ReadingFormat.history(history)
            ])
        output.lineColours = [
            ReadingFormat.warning(load, warn: number(settings, "warnLoad", 80), alarm: 95),
            ReadingFormat.warning(
                temperature, warn: number(settings, "warnTemperature", 85), alarm: 95)
        ]
        return output
    }

    static func memory(
        _ reading: MemoryReading, history: [Double], top: TopProcesses
    )
        -> WidgetOutput
    {
        var output = WidgetOutput(
            label: ReadingFormat.percent(reading.percent) + "\n"
                + ReadingFormat.bytes(reading.used),
            values: [
                "percent": ReadingFormat.percent(reading.percent),
                "used": ReadingFormat.bytesLong(reading.used),
                "total": ReadingFormat.bytesLong(reading.total),
                "app": ReadingFormat.bytesLong(reading.app),
                "wired": ReadingFormat.bytesLong(reading.wired),
                "compressed": ReadingFormat.bytesLong(reading.compressed),
                "cached": ReadingFormat.bytesLong(reading.cached),
                "swap": ReadingFormat.bytesLong(reading.swapUsed),
                "pressure": reading.pressure,
                "history": ReadingFormat.history(history),
                "top": top.byMemory()
            ])
        let colour =
            reading.pressureLevel >= 4 ? "#f87171" : reading.pressureLevel >= 2 ? "#fbbf24" : nil
        output.lineColours = [colour, nil]
        return output
    }

    static func network(
        _ reading: NetworkCounters, down: Double, up: Double, history: [Double]
    )
        -> WidgetOutput
    {
        WidgetOutput(
            label: ReadingFormat.rate(up) + "\n" + ReadingFormat.rate(down),
            values: [
                "up": ReadingFormat.rate(up),
                "down": ReadingFormat.rate(down),
                "interface": reading.interface ?? "Not connected",
                "address": reading.address ?? "--",
                "received": ReadingFormat.bytesLong(reading.received),
                "sent": ReadingFormat.bytesLong(reading.sent),
                "history": ReadingFormat.history(history)
            ])
    }

    static func battery(
        _ reading: BatteryReading, settings: [String: SettingValue]
    )
        -> WidgetOutput
    {
        let percent = "\(reading.percent)%"
        let showPercent = settings["showPercent"] != .bool(false)
        var output = WidgetOutput(
            label: showPercent ? percent : "",
            values: [
                "percent": percent,
                "source": reading.source,
                "state": reading.state,
                "remaining": reading.minutesLeft.map(ReadingFormat.duration) ?? "Calculating…",
                "remainingLabel": reading.charging ? "Until full" : "Time remaining",
                "cycles": reading.cycles.map(String.init) ?? "--",
                "health": reading.health.map { "\($0)%" } ?? "--",
                "lowPower": reading.lowPowerMode ? "On" : "Off"
            ])
        output.icon = reading.glyph
        let low = Int(number(settings, "lowAt", 10))
        if reading.percent <= low && !reading.onAdapter {
            output.iconColour = "#f87171"
            output.colour = "#f87171"
        } else if reading.charging {
            output.iconColour = "#4ade80"
        } else if reading.lowPowerMode {
            output.iconColour = "#fbbf24"
        }
        return output
    }
}
