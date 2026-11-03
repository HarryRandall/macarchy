import Foundation

public enum BorderCommand {
    public static func arguments(values: [String: String], theme: Theme?) -> [String] {
        let visible = values["BORDERS_VISIBLE"] != "false"
        let excluded = values["BORDERS_BLACKLIST"] ?? "iPhone Mirroring"
        let active = theme?.colors.borderActive.map(Theme.argb) ?? "0xff45e8ff"
        let inactive = theme?.colors.borderInactive.map(Theme.argb) ?? "0x00000000"
        let style = values["BORDER_STYLE"] ?? "round"
        // Rounded corners need the doubled backing to look smooth; square
        // ones look the same without it, at a quarter of the pixels. It is
        // always given, since a running borders keeps any option left out.
        return [
            "width=\(visible ? values["BORDER_WIDTH"] ?? "6.0" : "0.0")",
            "style=\(style)", "hidpi=\(style == "square" ? "off" : "on")",
            "blacklist=\(excluded)",
            "active_color=\(visible ? active : "0x00000000")",
            "inactive_color=\(visible ? inactive : "0x00000000")"
        ]
    }
}
