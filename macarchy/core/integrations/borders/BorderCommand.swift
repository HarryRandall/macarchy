import Foundation

public enum BorderCommand {
    public static func arguments(values: [String: String], theme: Theme?) -> [String] {
        let visible = values["BORDERS_VISIBLE"] != "false"
        let excluded = values["BORDERS_BLACKLIST"] ?? "iPhone Mirroring"
        return [
            "width=\(visible ? values["BORDER_WIDTH"] ?? "6.0" : "0.0")",
            "style=\(values["BORDER_STYLE"] ?? "round")", "hidpi=on", "background_color=0x00000000",
            "blacklist=\(excluded)",
            "active_color=\(visible ? theme?.colors.borderActive ?? "0xff45e8ff" : "0x00000000")",
            "inactive_color=\(visible ? theme?.colors.borderInactive ?? "0x00000000" : "0x00000000")"
        ]
    }
}
