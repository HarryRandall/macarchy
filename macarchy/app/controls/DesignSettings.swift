import Foundation
import Observation

/// Debug builds watch presentation data without restarting the app or touching desktop settings.
@MainActor
@Observable
final class DesignSettings {
    static let shared = DesignSettings()
    var values = Values()
    var reloadError: String?
    private var lastData: Data?

    struct Values: Codable {
        var sidebarWidth: Double = 210
        var pageWidth: Double = 960
        var cardRadius: Double = 14
        var gridSpacing: Double = 18
        var workshopTitle: String = "Find your next look."
        var workshopSubtitle: String = "Considered details. A completely different desktop."
        var homeTitle: String = "A space that works for you."
        var listings: [WorkshopItem] = WorkshopItem.samples
    }

    func watch() async {
        #if DEBUG
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appending(path: "design/appearance.json")
        while !Task.isCancelled {
            do {
                let data = try Data(contentsOf: file)
                if data != lastData {
                    let decoded = try JSONDecoder().decode(Values.self, from: data)
                    guard (180...280).contains(decoded.sidebarWidth),
                        (640...1400).contains(decoded.pageWidth),
                        (0...30).contains(decoded.cardRadius),
                        (8...36).contains(decoded.gridSpacing),
                        Set(decoded.listings.map(\.id)).count == decoded.listings.count
                    else { throw CocoaError(.coderInvalidValue) }
                    values = decoded
                    lastData = data
                }
                // Assigning every tick republished this observable once a
                // second, which invalidated every page that reads a design
                // value — visible as a stutter while scrolling.
                if reloadError != nil { reloadError = nil }
            } catch {
                let message = "Design reload: \(error.localizedDescription)"
                if reloadError != message { reloadError = message }
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { break }
        }
        #endif
    }
}
