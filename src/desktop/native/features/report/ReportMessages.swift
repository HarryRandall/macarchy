import Foundation

struct ReportPrepareParams: Decodable { var description: String }
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
