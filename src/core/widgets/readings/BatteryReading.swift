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
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
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
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        return nil
    }

    private static func smartBattery() -> (cycles: Int?, health: Int?) {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }
        let design = number("DesignCapacity")
        let full = number("AppleRawMaxCapacity") ?? number("NominalChargeCapacity")
        let health = design.flatMap { design in full.map { min(100, $0 * 100 / max(design, 1)) } }
        return (number("CycleCount"), health)
    }
}
