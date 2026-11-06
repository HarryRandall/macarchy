import Macarchy

/// Source descriptions refer to the existing widget, not a replacement sensor.
struct ComponentSource {
    let title: String
    let readings: [String]
    let samples: [(String, [String])]
    let icons: [String]

    static func describe(_ component: BarComponent) -> ComponentSource {
        if component.isCustom {
            return .init(
                title: component.kind == "spacer" ? "Spacer" : "Static text",
                readings: [], samples: [], icons: ["●", "★", "◆"])
        }
        switch component.id {
        case "cpu", "gpu":
            return .init(
                title: "Built-in · \(component.title)", readings: ["Load", "Temperature"],
                samples: [
                    ("Idle", ["0.0%", "35.0°"]), ("100%", ["100.0%", "99.9°"]),
                    ("Widest", ["100.0%", "99.9°"]), ("Unavailable", ["--", "--"])
                ],
                icons: component.id == "cpu" ? ["⚙", "▦", "●"] : ["▧", "◆", "▦"])
        case "ram":
            return .init(
                title: "Built-in · Memory", readings: ["Memory pressure", "Used GiB"],
                samples: [
                    ("Idle", ["0.0%", "0.0G"]), ("100%", ["100.0%", "99.9G"]),
                    ("Widest", ["100.0%", "99.9G"]), ("Unavailable", ["--", "--"])
                ],
                icons: ["▤", "▥", "▦"])
        case "network":
            return .init(
                title: "Built-in · Network", readings: ["Upload MB/s", "Download MB/s"],
                samples: [
                    ("Idle", ["0.0MB/s", "0.0MB/s"]), ("Busy", ["24.8MB/s", "99.9MB/s"]),
                    ("Widest", ["99.9MB/s", "99.9MB/s"]), ("Unavailable", ["--", "--"])
                ],
                icons: ["↕", "⇅", "↑↓"])
        case "battery":
            return .init(
                title: "Built-in · Battery", readings: ["Battery percentage"],
                samples: [
                    ("Empty", ["0%"]), ("Full", ["100%"]),
                    ("Widest", ["100%"]), ("Unavailable", ["--"])
                ], icons: ["▰", "▱", "●"])
        case "calendar":
            return .init(
                title: "Built-in · Clock", readings: ["Date and time"],
                samples: [
                    ("Short", ["00:00"]), ("Widest", ["Wed 30 Sep 11:59 PM"]),
                    ("Unavailable", ["--"])
                ], icons: ["◷", "◴", "◷"])
        default:
            return .init(
                title: "Existing widget", readings: [], samples: [], icons: ["●", "◆", "★"])
        }
    }
}
