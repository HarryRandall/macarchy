import Darwin
import Foundation
import IOKit

/// What each core has done since boot, from the kernel's tick counters.
/// Load is the share of ticks spent busy between two of these.
struct CoreTicks: Equatable, Sendable {
    var busy: UInt64
    var total: UInt64

    /// Every core's counters, in the kernel's order: efficiency cores first
    /// on Apple Silicon, then performance cores.
    static func read() -> [CoreTicks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard
            host_processor_info(
                mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount)
                == KERN_SUCCESS, let info
        else { return [] }
        defer {
            vm_deallocate(
                mach_task_self_, vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        return (0..<Int(count)).map { core in
            let base = core * states
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            return CoreTicks(busy: user + system + nice, total: user + system + nice + idle)
        }
    }

    /// Each core's load from `earlier` to `later`, 0 to 100.
    static func loads(from earlier: [CoreTicks], to later: [CoreTicks]) -> [Double] {
        guard earlier.count == later.count else { return later.map { _ in 0 } }
        return zip(earlier, later).map { old, new in
            let total = new.total &- old.total
            guard total > 0 else { return 0 }
            return min(100, Double(new.busy &- old.busy) / Double(total) * 100)
        }
    }
}

/// The Mac's processor as it describes itself.
struct ProcessorInfo: Equatable, Sendable {
    var chip: String
    var performance: Int
    var efficiency: Int

    static let current = ProcessorInfo(
        chip: sysctlString("machdep.cpu.brand_string") ?? "Apple silicon",
        performance: sysctlInt("hw.perflevel0.logicalcpu") ?? 0,
        efficiency: sysctlInt("hw.perflevel1.logicalcpu") ?? 0)

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}

/// How busy the GPU is, 0 to 100, as Activity Monitor's GPU History reads it.
enum GPUUsage {
    static func read() -> Double? {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
                == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        var busiest: Double?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            guard
                IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
                    == KERN_SUCCESS,
                let dictionary = properties?.takeRetainedValue() as? [String: Any],
                let statistics = dictionary["PerformanceStatistics"] as? [String: Any],
                let usage = statistics["Device Utilization %"] as? NSNumber
            else { continue }
            busiest = max(busiest ?? 0, usage.doubleValue)
        }
        return busiest.map { min(100, $0) }
    }
}
