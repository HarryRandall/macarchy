import AppKit
import Macarchy
import SwiftUI

/// The Macarchy logo, drawn from the bundled SVG.
enum BrandMark {
    /// The logo in its own colours, for the window.
    static let colour: NSImage? = image(strokeWidth: 7, template: false)

    /// A single-colour version for the menu bar, which macOS tints to match.
    /// Thicker strokes keep the outline legible at 16 points, and the window
    /// dots are dropped because a template image cannot keep their colours.
    static let menuBar: NSImage? = image(strokeWidth: 34, template: true)

    private static func image(strokeWidth: Int, template: Bool) -> NSImage? {
        guard let url = Paths.resources?.appending(path: "logo.svg"),
            var svg = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        svg = svg.replacingOccurrences(
            of: "stroke-width=\"7\"", with: "stroke-width=\"\(strokeWidth)\"")
        if template {
            svg = svg.replacingOccurrences(
                of: "<circle[^>]*/>", with: "", options: .regularExpression)
        }
        guard let data = svg.data(using: .utf8), let image = NSImage(data: data) else {
            return nil
        }
        image.isTemplate = template
        return image
    }
}
