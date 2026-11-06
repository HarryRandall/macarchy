import Darwin
import Foundation
import IOKit
import Metal

/// The GPU as Activity Monitor's GPU History reads it: how busy it is, 0 to
/// 100, how much memory it holds, how many cores it has, and the GPU time
/// each app has used since it started.
struct GPUReading: Equatable, Sendable {
    var load: Double
    /// Bytes of memory the GPU holds now.
    var memory: UInt64?
    var cores: Int?
    /// Nanoseconds of GPU time by process ID, which only grows.
    var time: [Int32: UInt64] = [:]

    /// The most memory macOS lets the GPU hold, which Metal reports.
    static let memoryLimit: UInt64? = MTLCreateSystemDefaultDevice()?.recommendedMaxWorkingSetSize

    static func read() -> GPUReading? {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
                == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        var busiest: GPUReading?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let properties = properties(of: service),
                let statistics = properties["PerformanceStatistics"] as? [String: Any],
                let usage = statistics["Device Utilization %"] as? NSNumber,
                usage.doubleValue >= busiest?.load ?? 0
            else { continue }
            busiest = GPUReading(
                load: min(100, usage.doubleValue),
                memory: (statistics["In use system memory"] as? NSNumber)?.uint64Value,
                cores: (properties["gpu-core-count"] as? NSNumber)?.intValue,
                time: time(under: service))
        }
        return busiest
    }

    private static func properties(of entry: io_registry_entry_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard
            IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)
                == KERN_SUCCESS
        else { return nil }
        return properties?.takeRetainedValue() as? [String: Any]
    }

    /// Each app's connections to the GPU name it as `pid 396, WindowServer`
    /// and count the GPU time each of its queues has used.
    private static func time(under accelerator: io_registry_entry_t) -> [Int32: UInt64] {
        var children: io_iterator_t = 0
        guard
            IORegistryEntryGetChildIterator(accelerator, kIOServicePlane, &children) == KERN_SUCCESS
        else { return [:] }
        defer { IOObjectRelease(children) }
        var time: [Int32: UInt64] = [:]
        while case let child = IOIteratorNext(children), child != 0 {
            defer { IOObjectRelease(child) }
            guard let properties = properties(of: child),
                let creator = properties["IOUserClientCreator"] as? String,
                let pid = pid(creator), let usage = properties["AppUsage"] as? [[String: Any]]
            else { continue }
            time[pid, default: 0] += usage.reduce(0) {
                $0 + ((($1["accumulatedGPUTime"] as? NSNumber)?.uint64Value) ?? 0)
            }
        }
        return time
    }

    /// `396` from `pid 396, WindowServer`.
    static func pid(_ creator: String) -> Int32? {
        guard creator.hasPrefix("pid ") else { return nil }
        return Int32(creator.dropFirst(4).prefix { $0.isNumber })
    }

    /// Each app's share of the GPU between two readings, `seconds` apart,
    /// busiest first, with helpers counted towards their app.
    static func apps(
        from earlier: [Int32: UInt64], to later: [Int32: UInt64], seconds: Double,
        name: (Int32) -> String? = processName
    ) -> [(name: String, share: Double)] {
        guard seconds > 0 else { return [] }
        var shares: [String: Double] = [:]
        for (pid, time) in later {
            guard let before = earlier[pid], time > before, let process = name(pid) else {
                continue
            }
            let share = Double(time - before) / (seconds * 1_000_000_000) * 100
            shares[TopProcesses.appName(process), default: 0] += share
        }
        return shares.map { (name: $0.key, share: min($0.value, 100)) }
            .filter { $0.share >= 0.1 }
            .sorted { $0.share > $1.share }
    }

    /// The program's own name, which is not cut short as the registry's is.
    static func processName(_ pid: Int32) -> String? {
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: path)).lastPathComponent
    }
}
