import Darwin
import Foundation

/// Bytes moved since boot over the interfaces that reach the network, and
/// the address of the busiest one.
struct NetworkCounters: Equatable, Sendable {
    var received: UInt64
    var sent: UInt64
    /// The interface that has moved the most, such as `en0`.
    var interface: String?
    var address: String?

    static func read() -> NetworkCounters {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else {
            return NetworkCounters(received: 0, sent: 0)
        }
        defer { freeifaddrs(first) }
        var totals: [String: (received: UInt64, sent: UInt64)] = [:]
        var addresses: [String: String] = [:]
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let pointee = entry.pointee
            let name = String(cString: pointee.ifa_name)
            guard counts(name, flags: pointee.ifa_flags), let address = pointee.ifa_addr else {
                continue
            }
            switch Int32(address.pointee.sa_family) {
            case AF_LINK:
                guard let data = pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else {
                    continue
                }
                totals[name] = (UInt64(data.pointee.ifi_ibytes), UInt64(data.pointee.ifi_obytes))
            case AF_INET:
                addresses[name] = ipv4(address)
            default: break
            }
        }
        let busiest = totals.max {
            $0.value.received + $0.value.sent < $1.value.received + $1.value.sent
        }
        return NetworkCounters(
            received: totals.values.reduce(0) { $0 + $1.received },
            sent: totals.values.reduce(0) { $0 + $1.sent },
            interface: busiest?.key, address: busiest.flatMap { addresses[$0.key] })
    }

    /// Ethernet, Wi-Fi and Thunderbolt interfaces that are up, not the
    /// loopback or the virtual ones VPNs and Docker add.
    private static func counts(_ name: String, flags: UInt32) -> Bool {
        name.hasPrefix("en") && flags & UInt32(IFF_UP) != 0 && flags & UInt32(IFF_LOOPBACK) == 0
    }

    private static func ipv4(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard
            getnameinfo(
                address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
                NI_NUMERICHOST) == 0
        else { return nil }
        return String(cString: host)
    }
}
