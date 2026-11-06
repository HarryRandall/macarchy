import Foundation
import IOKit
import IOKit.ps

/// The battery as the Battery menu describes it, with the condition figures
/// System Information shows.
struct BatteryReading: Equatable, Sendable {
    var percent: Int
    var onAdapter: Bool
    var charging: Bool
    var charged: Bool
    /// Minutes until empty, or until full while charging; nil while it works it out.
    var minutesLeft: Int?
    var cycles: Int?
    /// Full charge capacity as a share of the design capacity.
    var health: Int?
    var lowPowerMode: Bool
    /// The battery's own temperature, in degrees.
    var temperature: Double?
    /// Watts going into the battery, or coming out of it when negative.
    var watts: Double?

    var source: String { onAdapter ? "Power Adapter" : "Battery" }

    var state: String {
        if charged { return "Fully Charged" }
        if charging { return "Charging" }
        return onAdapter ? "Not Charging" : "On Battery"
    }

    /// The battery glyph for the charge, or the plug while on power.
    var glyph: String {
        if onAdapter { return "\u{10088B}" }
        switch percent {
        case 88...: return "\u{1006E8}"
        case 63...: return "\u{100EB8}"
        case 38...: return "\u{100EB6}"
        case 13...: return "\u{1006E9}"
        default: return "\u{1006EA}"
        }
    }

    /// The first internal battery, or nil on a Mac without one.
    static func read() -> BatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            // Around sleep, wake and a change of power source the entry can
            // come without its charge; reading that as 0% would flag the
            // battery as low, so there is no reading until it is back.
            guard let current = description[kIOPSCurrentCapacityKey] as? Int else { return nil }
            let maximum = max(description[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let minutes =
                charging
                ? description[kIOPSTimeToFullChargeKey] as? Int
                : description[kIOPSTimeToEmptyKey] as? Int
            let condition = smartBattery()
            return BatteryReading(
                percent: current * 100 / maximum,
                onAdapter: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                charging: charging,
                charged: description[kIOPSIsChargedKey] as? Bool ?? false,
                minutesLeft: minutes.flatMap { $0 > 0 ? $0 : nil },
                cycles: condition.cycles, health: condition.health,
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                temperature: condition.temperature ?? SMCSensors.shared.read().battery,
                watts: condition.watts)
        }
        return nil
    }

    /// The condition figures System Information shows, and the battery's
    /// temperature and power.
    private struct Condition {
        var cycles: Int?
        var health: Int?
        var temperature: Double?
        var watts: Double?
    }

    private static func smartBattery() -> Condition {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return Condition() }
        defer { IOObjectRelease(service) }
        // Newer macOS keeps most figures only in BatteryData.
        let data =
            IORegistryEntryCreateCFProperty(
                service, "BatteryData" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any]
        func number(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int ?? data?[key] as? Int
        }
        let design = number("DesignCapacity")
        let full = number("AppleRawMaxCapacity") ?? number("NominalChargeCapacity")
        let health = design.flatMap { design in full.map { min(100, $0 * 100 / max(design, 1)) } }
        // Hundredths of a degree; current in milliamps, signed though the
        // registry stores it unsigned, and millivolts.
        let temperature = number("Temperature").map { Double($0) / 100 }
        let current =
            (IORegistryEntryCreateCFProperty(
                service, "Amperage" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber)?.int64Value
        let watts = current.flatMap { current in
            number("Voltage").map { Double(current) * Double($0) / 1_000_000 }
        }
        return Condition(
            cycles: number("CycleCount"), health: health, temperature: temperature, watts: watts)
    }
}

/// Energy Mode as the Battery menu shows it.
enum EnergyMode {
    /// From `pmset -g`: `powermode` 1 is Low Power and 2 High Power. Macs
    /// without the setting have only Low Power Mode, on or off.
    static func parse(_ settings: String, lowPowerMode: Bool) -> String {
        let mode = settings.split(separator: "\n").lazy
            .map { $0.split(separator: " ", omittingEmptySubsequences: true) }
            .first { $0.first == "powermode" }?.last
        switch mode {
        case "1": return "Low Power"
        case "2": return "High Power"
        case nil: return lowPowerMode ? "Low Power" : "Automatic"
        default: return "Automatic"
        }
    }

    static func read(lowPowerMode: Bool) async -> String {
        let result = await CommandRunner.run("/usr/bin/pmset", ["-g"], timeout: 2)
        return parse(result.ok ? result.stdout : "", lowPowerMode: lowPowerMode)
    }
}
