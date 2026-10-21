import AppKit
import SwiftUI

extension Color {
    /// How a colour is spelled in the file it lives in. borders and sketchybar
    /// want 0xAARRGGBB; FIREFOX_ACCENT wants #RRGGBB.
    enum MacarchyFormat { case argb, rgb }

    /// Renders back to the string form the target expects. Round-trips with
    /// `init?(macarchyHex:)`, so editing a colour and saving cannot silently
    /// change its notation.
    func macarchyString(_ format: MacarchyFormat) -> String? {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let channel = { (component: CGFloat) in Int((component * 255).rounded()) }
        let r = channel(srgb.redComponent)
        let g = channel(srgb.greenComponent)
        let b = channel(srgb.blueComponent)
        switch format {
        case .argb:
            return String(format: "0x%02x%02x%02x%02x", channel(srgb.alphaComponent), r, g, b)
        case .rgb: return String(format: "#%02x%02x%02x", r, g, b)
        }
    }

    /// Alpha channel of a `0xAARRGGBB` value, so a fully transparent border can
    /// be reported as "not drawn" rather than silently rendering as nothing.
    static func macarchyAlpha(_ raw: String?) -> Double? {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return nil
        }
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        guard text.count == 8, let value = UInt64(text, radix: 16) else { return 1 }
        return Double((value >> 24) & 0xFF) / 255
    }

    /// Parses the `0xAARRGGBB` form that borders and sketchybar both use,
    /// and the plain `#RRGGBB` used for FIREFOX_ACCENT.
    init?(macarchyHex raw: String?) {
        guard var text = raw?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            return nil
        }
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        if text.hasPrefix("#") { text = String(text.dropFirst()) }
        guard let value = UInt64(text, radix: 16) else { return nil }

        let a: Double
        let r: Double
        let g: Double
        let b: Double
        switch text.count {
        case 8:
            a = Double((value >> 24) & 0xFF) / 255
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        case 6:
            a = 1
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
