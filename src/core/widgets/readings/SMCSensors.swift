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
    private var keys: (cpu: [UInt32], gpu: [UInt32])?

    /// The average of each group's sensors that read a believable value.
    func read() -> Temperatures {
        lock.lock()
        defer { lock.unlock() }
        guard open() else { return Temperatures() }
        let keys = self.keys ?? findKeys()
        self.keys = keys
        return Temperatures(cpu: average(keys.cpu), gpu: average(keys.gpu))
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

    private func findKeys() -> (cpu: [UInt32], gpu: [UInt32]) {
        var count = Message()
        count.key = Self.code("#KEY")
        count.dataSize = 4
        count.command = Command.readBytes.rawValue
        guard let reply = call(count) else { return ([], []) }
        let total = withUnsafeBytes(of: reply.data) {
            UInt32(bigEndian: $0.load(as: UInt32.self))
        }
        var cpu: [UInt32] = []
        var gpu: [UInt32] = []
        for index in 0..<min(total, 10_000) {
            var request = Message()
            request.command = Command.keyAtIndex.rawValue
            request.index = index
            guard let found = call(request) else { continue }
            let name = Self.name(found.key)
            let group =
                name.hasPrefix("Tp") || name.hasPrefix("Te") ? 1 : name.hasPrefix("Tg") ? 2 : 0
            guard group != 0, let value = float(found.key), Self.believable(value) else { continue }
            if group == 1 { cpu.append(found.key) } else { gpu.append(found.key) }
        }
        return (cpu, gpu)
    }

    private func average(_ keys: [UInt32]) -> Double? {
        let values = keys.compactMap(float).filter(Self.believable)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    static func believable(_ value: Double) -> Bool { value > 5 && value < 125 }

    static func code(_ text: String) -> UInt32 {
        text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func name(_ code: UInt32) -> String {
        String(bytes: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) }, encoding: .ascii) ?? ""
    }
}
