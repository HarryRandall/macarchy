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
        /// The die temperature over the same minute.
        var temperatures: [Double] = []
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
                "temperatures": ReadingFormat.history(sample.temperatures),
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

    /// One GPU reading, with the minute before it.
    struct GPUSample: Equatable, Sendable {
        var load: Double
        var temperature: Double?
        var history: [Double]
        /// The temperature over the same minute.
        var temperatures: [Double] = []
        var memory: UInt64?
        var memoryLimit: UInt64?
        var cores: Int?
        /// The busiest apps as `Name:12.4%,…`.
        var top = ""
    }

    static func gpu(_ sample: GPUSample, settings: [String: SettingValue]) -> WidgetOutput {
        let (load, temperature) = (sample.load, sample.temperature)
        var values = [
            "load": ReadingFormat.percent(load),
            "load.short": ReadingFormat.wholePercent(load),
            "temperature": ReadingFormat.degrees(temperature),
            "history": ReadingFormat.history(sample.history),
            "temperatures": ReadingFormat.history(sample.temperatures),
            "cores": sample.cores.map { "\($0)-core" } ?? "",
            "top": sample.top
        ]
        if let memory = sample.memory {
            values["memory"] = ReadingFormat.bytesLong(memory)
            values["memory.gb"] = ReadingFormat.gigabytes(memory)
        }
        if let limit = sample.memoryLimit {
            let whole = String(format: "%.0f GB", (Double(limit) / 1_073_741_824).rounded())
            values["memory.limit"] = whole
            values["memory.limit.gb"] = ReadingFormat.gigabytes(limit)
            values["memory.summary"] =
                sample.memory.map { "\(ReadingFormat.bytesLong($0)) of \(whole)" } ?? "--"
        }
        var output = WidgetOutput(
            label: ReadingFormat.percent(load) + "\n" + ReadingFormat.degrees(temperature),
            values: values)
        output.lineColours = [
            ReadingFormat.warning(load, warn: number(settings, "warnLoad", 80), alarm: 95),
            ReadingFormat.warning(
                temperature, warn: number(settings, "warnTemperature", 85), alarm: 95)
        ]
        return output
    }

    static func memory(
        _ reading: MemoryReading, history: [Double], swapHistory: [Double] = [],
        top: TopProcesses
    )
        -> WidgetOutput
    {
        let total = Double(reading.total) / 1_073_741_824
        var output = WidgetOutput(
            label: ReadingFormat.percent(reading.percent) + "\n"
                + ReadingFormat.bytes(reading.used),
            values: [
                "percent": ReadingFormat.percent(reading.percent),
                "percent.short": ReadingFormat.wholePercent(reading.percent),
                "used": ReadingFormat.bytesLong(reading.used),
                "total": ReadingFormat.bytesLong(reading.total),
                "summary": String(
                    format: "%.1f of %.0f GB", Double(reading.used) / 1_073_741_824, total),
                "app": ReadingFormat.bytesLong(reading.app),
                "wired": ReadingFormat.bytesLong(reading.wired),
                "compressed": ReadingFormat.bytesLong(reading.compressed),
                "cached": ReadingFormat.bytesLong(reading.cached),
                "swap": ReadingFormat.bytesLong(reading.swapUsed),
                "swap.short": String(format: "%.1fG", Double(reading.swapUsed) / 1_073_741_824),
                "app.gb": ReadingFormat.gigabytes(reading.app),
                "wired.gb": ReadingFormat.gigabytes(reading.wired),
                "compressed.gb": ReadingFormat.gigabytes(reading.compressed),
                "cached.gb": ReadingFormat.gigabytes(reading.cached),
                "total.gb": ReadingFormat.gigabytes(reading.total),
                "pressure": reading.pressure,
                "history": ReadingFormat.history(history),
                "swapHistory": swapHistory.map { String(format: "%.2f", $0) }
                    .joined(separator: ","),
                "top": top.byMemory()
            ])
        let colour =
            reading.pressureLevel >= 4 ? "#f87171" : reading.pressureLevel >= 2 ? "#fbbf24" : nil
        output.lineColours = [colour, nil]
        return output
    }

    /// One network reading: rates in bytes a second and their minute in
    /// kilobytes a second.
    struct NetworkSample: Equatable, Sendable {
        var down: Double
        var up: Double
        var history: [Double]
        var upHistory: [Double] = []
        var wifi: WiFiReading?
        var router: String?
    }

    static func network(_ reading: NetworkCounters, _ sample: NetworkSample) -> WidgetOutput {
        let wifi = sample.wifi.flatMap { $0.interface == reading.interface ? $0 : nil }
        let connected = reading.interface != nil
        let kind = wifi != nil ? "Wi-Fi" : connected ? "Ethernet" : "Not connected"
        return WidgetOutput(
            label: ReadingFormat.rate(sample.up) + "\n" + ReadingFormat.rate(sample.down),
            values: [
                "up": ReadingFormat.rate(sample.up),
                "down": ReadingFormat.rate(sample.down),
                "interface": reading.interface ?? "Not connected",
                "address": reading.address ?? "--",
                "received": ReadingFormat.bytesLong(reading.received),
                "sent": ReadingFormat.bytesLong(reading.sent),
                "history": ReadingFormat.history(sample.history),
                "upHistory": ReadingFormat.history(sample.upHistory),
                "status": connected ? "Connected" : "Not connected",
                "kind": kind,
                "icon": wifi != nil
                    ? "wifi" : connected ? "cable.connector.horizontal" : "wifi.slash",
                "link": [reading.interface, reading.address].compactMap { $0 }
                    .joined(separator: " · "),
                "signal": wifi.map { String($0.bars) } ?? "",
                "band": wifi?.band ?? "",
                "channel": wifi?.channel.map { "Ch \($0)" } ?? "",
                "rate": wifi.map { String(format: "%.0f Mb/s", $0.rate) } ?? "",
                "rssi": wifi.map { "\($0.rssi) dBm" } ?? "",
                "router": sample.router ?? "--"
            ])
    }

    /// One battery reading, with what has been kept of the last while.
    struct BatterySample: Equatable, Sendable {
        var levels: [Double] = []
        var temperatures: [Double] = []
        var rates: [Double] = []
        var energyMode = "Automatic"
        var energyApps = ""
    }

    static func battery(
        _ reading: BatteryReading, _ sample: BatterySample = BatterySample(),
        settings: [String: SettingValue]
    )
        -> WidgetOutput
    {
        let percent = "\(reading.percent)%"
        let showPercent = settings["showPercent"] != .bool(false)
        let state =
            reading.charging
            ? " · Charging"
            : reading.charged
                ? " · Charged"
                : reading.onAdapter ? " · On power" : ""
        let short =
            reading.onAdapter && !reading.charging
            ? "On power" : reading.minutesLeft.map(ReadingFormat.hours) ?? "--"
        var output = WidgetOutput(
            label: showPercent ? percent : "",
            values: [
                "percent": percent,
                "headline": percent + state,
                "source": reading.source,
                "state": reading.state,
                "remaining": reading.minutesLeft.map(ReadingFormat.duration) ?? "Calculating…",
                "remaining.short": short,
                "remainingLabel": reading.charging ? "Until full" : "Time remaining",
                "cycles": reading.cycles.map(String.init) ?? "--",
                "health": reading.health.map { "\($0)%" } ?? "--",
                "lowPower": reading.lowPowerMode ? "On" : "Off",
                "temperature": ReadingFormat.degrees(reading.temperature),
                "rate": reading.watts.map { String(format: "%.0f W", max($0, 0)) } ?? "--",
                "charging": reading.charging ? "yes" : "",
                "notCharging": reading.charging ? "" : "yes",
                "levels": ReadingFormat.history(sample.levels),
                "temperatures": ReadingFormat.history(sample.temperatures),
                "rates": ReadingFormat.history(sample.rates),
                "energyMode": sample.energyMode,
                "energyApps": sample.energyApps
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
