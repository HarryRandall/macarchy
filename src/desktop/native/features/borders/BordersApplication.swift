import AppKit
import Foundation
import Macarchy

struct BordersApplication: Encodable, Sendable {
    var name: String
    var icon: String?

    private enum CodingKeys: String, CodingKey { case name, icon }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
    }

    @MainActor
    static func icon(named name: String) -> String? {
        guard !name.contains("/"), name != ".", name != ".." else { return nil }
        for root in [
            "/Applications", "/System/Applications",
            Paths.home.appending(path: "Applications").path,
            "/System/Applications/Utilities"
        ] {
            let path = root + "/" + name + ".app"
            guard FileManager.default.fileExists(atPath: path) else { continue }
            guard let tiff = NSWorkspace.shared.icon(forFile: path).tiffRepresentation,
                let image = NSBitmapImageRep(data: tiff),
                let png = image.representation(using: .png, properties: [:])
            else { return nil }
            return "data:image/png;base64," + png.base64EncodedString()
        }
        return nil
    }
}
