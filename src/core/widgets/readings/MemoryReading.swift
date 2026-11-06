import Darwin
import Foundation

/// Memory as Activity Monitor counts it: used is app memory, wired and
/// compressed together.
struct MemoryReading: Equatable, Sendable {
    var total: UInt64
    var app: UInt64
    var wired: UInt64
    var compressed: UInt64
    var cached: UInt64
    var swapUsed: UInt64
    /// The kernel's own judgement: 1 normal, 2 warning, 4 critical.
    var pressureLevel: Int

    var used: UInt64 { app + wired + compressed }
    var percent: Double { total == 0 ? 0 : min(100, Double(used) / Double(total) * 100) }

    var pressure: String {
        switch pressureLevel {
        case 4: "Critical"
        case 2: "Warning"
        default: "Normal"
        }
    }

    static func read() -> MemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = UInt64(getpagesize())
        let anonymous = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        return MemoryReading(
            total: ProcessInfo.processInfo.physicalMemory,
            app: (anonymous > purgeable ? anonymous - purgeable : 0) * page,
            wired: UInt64(stats.wire_count) * page,
            compressed: UInt64(stats.compressor_page_count) * page,
            cached: (UInt64(stats.external_page_count) + purgeable) * page,
            swapUsed: swapUsed(),
            pressureLevel: pressureLevel())
    }

    private static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    private static func pressureLevel() -> Int {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0
        else { return 1 }
        return Int(level)
    }
}
