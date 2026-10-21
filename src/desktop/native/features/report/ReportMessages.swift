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
struct ReportState: Encodable {
    var body: String
    var token: String
}
struct ReportOpened: Encodable { var copied: Bool }
