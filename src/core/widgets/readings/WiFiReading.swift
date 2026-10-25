import CoreWLAN
import Foundation
import SystemConfiguration

/// The Wi-Fi link as the Wi-Fi menu shows it when Option is held: signal,
/// channel and speed. The network's name needs Location Services, so it is
/// not read.
struct WiFiReading: Equatable, Sendable {
    var interface: String
    /// Signal strength in dBm, such as -58.
    var rssi: Int
    /// The link's transmit rate in megabits a second.
    var rate: Double
    var channel: Int?
    /// 2.4, 5 or 6 GHz.
    var band: String?

    /// Signal as Wi-Fi bars, 1 to 4.
    var bars: Int {
        if rssi >= -55 { return 4 }
        if rssi >= -65 { return 3 }
        return rssi >= -75 ? 2 : 1
    }

    static func read() -> WiFiReading? {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn(),
            let name = interface.interfaceName, interface.rssiValue() != 0
        else { return nil }
        let channel = interface.wlanChannel()
        let band: String? =
            switch channel?.channelBand {
            case .band2GHz: "2.4 GHz"
            case .band5GHz: "5 GHz"
            case .band6GHz: "6 GHz"
            default: nil
            }
        return WiFiReading(
            interface: name, rssi: interface.rssiValue(), rate: interface.transmitRate(),
            channel: channel?.channelNumber, band: band)
    }

    /// The router of the connection macOS is using, as Network settings
    /// shows it.
    static func router() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Macarchy" as CFString, nil, nil),
            let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                as? [String: Any]
        else { return nil }
        return global["Router"] as? String
    }
}
