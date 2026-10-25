import Foundation
import IOKit

/// Temperatures from the System Management Controller, as macmon and
/// Stats read them, without root or any tool installed.
///
/// Apple Silicon names its CPU die sensors `Tp…` and `Te…` and its GPU
/// sensors `Tg…`, each a 32-bit float. The list of keys is read once; after
/// that each reading is a handful of calls.
final class SMCSensors: @unchecked Sendable {
    static let shared = SMCSensors()

    struct Temperatures: Equatable, Sendable {
        var cpu: Double?
        var gpu: Double?
        var battery: Double?
    }

    /// The controller's request and reply, laid out as its kernel extension
    /// expects: 80 bytes, with the key info padded to 12. Only `key` to
    /// `index` and the first eight data bytes are read or written here.
    private struct Message {
        var key: UInt32 = 0
        var versionMajor: UInt8 = 0
        var versionMinor: UInt8 = 0
        var versionBuild: UInt8 = 0
        var versionReserved: UInt8 = 0
        var versionRelease: UInt16 = 0
        var limitVersion: UInt16 = 0
        var limitLength: UInt16 = 0
        var limitCPU: UInt32 = 0
        var limitGPU: UInt32 = 0
        var limitMemory: UInt32 = 0
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var attributes: UInt8 = 0
        var paddingA: UInt8 = 0
        var paddingB: UInt8 = 0
        var paddingC: UInt8 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var command: UInt8 = 0
        var index: UInt32 = 0
        var data: UInt64 = 0
        var dataB: UInt64 = 0
        var dataC: UInt64 = 0
        var dataD: UInt64 = 0
    }

    private enum Command: UInt8 {
        case readBytes = 5
        case keyAtIndex = 8
        case keyInfo = 9
    }

    private let lock = NSLock()
    private var connection: io_connect_t = 0
    /// Sensor keys by what they measure.
    private struct Keys {
        var cpu: [UInt32] = []
        var gpu: [UInt32] = []
        var battery: [UInt32] = []
    }
    private var keys: Keys?
    /// Each sensor's last believable value, and when it was read.
    private var last: [UInt32: (value: Double, at: Date)] = [:]

    /// The average of each group's sensors, each at its last believable value.
    func read() -> Temperatures {
        lock.lock()
        defer { lock.unlock() }
        guard open() else { return Temperatures() }
        let keys = self.keys ?? findKeys()
        self.keys = keys
        let now = Date()
        return Temperatures(
            cpu: average(keys.cpu, at: now), gpu: average(keys.gpu, at: now),
            battery: average(keys.battery, at: now))
    }

    private func open() -> Bool {
        if connection != 0 { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess
    }

    private func call(_ input: Message) -> Message? {
        var input = input
        var output = Message()
        var size = MemoryLayout<Message>.stride
        let result = IOConnectCallStructMethod(
            connection, 2, &input, MemoryLayout<Message>.stride, &output, &size)
        return result == kIOReturnSuccess && output.result == 0 ? output : nil
    }

    private func float(_ key: UInt32) -> Double? {
        var info = Message()
        info.key = key
        info.command = Command.keyInfo.rawValue
        guard let described = call(info), described.dataSize == 4,
            described.dataType == Self.code("flt ")
        else { return nil }
        var request = Message()
        request.key = key
        request.dataSize = 4
        request.command = Command.readBytes.rawValue
        guard let reply = call(request) else { return nil }
        let value = withUnsafeBytes(of: reply.data) { $0.load(as: Float.self) }
        return Double(value)
    }

    /// CPU sensors start `Tp` or `Te`, GPU ones `Tg` and the battery's `TB`.
    private func findKeys() -> Keys {
        var count = Message()
        count.key = Self.code("#KEY")
        count.dataSize = 4
        count.command = Command.readBytes.rawValue
        guard let reply = call(count) else { return Keys() }
        let total = withUnsafeBytes(of: reply.data) {
            UInt32(bigEndian: $0.load(as: UInt32.self))
        }
        var keys = Keys()
        for index in 0..<min(total, 10_000) {
            var request = Message()
            request.command = Command.keyAtIndex.rawValue
            request.index = index
            guard let found = call(request) else { continue }
            let name = Self.name(found.key)
            let group =
                name.hasPrefix("Tp") || name.hasPrefix("Te")
                ? 1 : name.hasPrefix("Tg") ? 2 : name.hasPrefix("TB") ? 3 : 0
            // Chosen by name and type, not by what they read now, which may be
            // one of the moments their values are nonsense.
            guard group != 0, float(found.key) != nil else { continue }
            switch group {
            case 1: keys.cpu.append(found.key)
            case 2: keys.gpu.append(found.key)
            default: keys.battery.append(found.key)
            }
        }
        return keys
    }

    /// Every few seconds the performance cores' sensors all report nonsense
    /// at once, such as -4° and 0°. Averaging only the sensors left would
    /// drop the reading by 25° and back, so a read where most sensors are
    /// out is ignored, and each sensor counts at its last believable value.
    private func average(_ keys: [UInt32], at now: Date) -> Double? {
        let read = keys.map { key in (key, float(key).flatMap { Self.believable($0) ? $0 : nil }) }
        let good = read.compactMap { key, value in value.map { (key, $0) } }
        // Judged against the sensors that have ever worked, since some never do.
        let working = keys.filter { last[$0] != nil }.count
        if Self.trusted(good: good.count, working: working, of: keys.count) {
            for (key, value) in good { last[key] = (value, now) }
        }
        let values = keys.compactMap { key in
            last[key].flatMap { now.timeIntervalSince($0.at) < 30 ? $0.value : nil }
        }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Whether a read is sound enough to learn from: three in four of the
    /// sensors that have worked gave a believable value, or, on the first
    /// read, half of them all.
    static func trusted(good: Int, working: Int, of total: Int) -> Bool {
        guard good > 0 else { return false }
        return working == 0 ? good * 2 >= total : good * 4 >= working * 3
    }

    /// A working chip is never below room temperature or above its limit.
    static func believable(_ value: Double) -> Bool { value >= 20 && value < 125 }

    static func code(_ text: String) -> UInt32 {
        text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func name(_ code: UInt32) -> String {
        String(bytes: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) }, encoding: .ascii) ?? ""
    }
}
