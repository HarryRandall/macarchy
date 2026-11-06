import Foundation

struct ReportPrepareParams: Decodable {
    var description: String
    /// Collect diagnostics again unless a collection is already running.
    var refresh: Bool
}
struct ReportCopyParams: Decodable { var token: String }
struct ReportOpenParams: Decodable {
    var token: String
    var title: String
}
struct ReportState: Codable {
    var body: String
    var token: String
}
struct ReportOpened: Codable { var copied: Bool }

extension BridgeEvent {
    /// The desktop may have changed while the window was away, so a report
    /// page that is showing collects its diagnostics again.
    static var reportInvalidated: BridgeEvent { BridgeEvent("report.invalidated") }
}
